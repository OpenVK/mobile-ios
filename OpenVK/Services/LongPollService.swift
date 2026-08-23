//
//  LongPollService.swift
//  OpenVK for iOS
//

import Foundation
import Combine

enum LongPollEvent {
    case newMessage(id: Int, flags: Int, peerId: Int, date: Date, text: String, attachments: [String: Any], fromId: Int, replyTo: Int?)
    case editMessage(id: Int, peerId: Int, text: String, attachments: [String: Any])
    case messageDeleted(id: Int, peerId: Int)
    case typing(peerId: Int, userIds: [Int])
    case chatUpdated(chatId: Int)
    case unreadCountChanged(count: Int)
}

final class LongPollService: ObservableObject {

    static let shared = LongPollService()

    @Published private(set) var isConnected = false
    @Published private(set) var unreadCount: Int = 0

    let events = PassthroughSubject<LongPollEvent, Never>()

    private var server: String?
    private var key: String?
    private var ts: Int?
    private var pts: Int?
    private var isRunning = false
    private var currentTask: URLSessionDataTask?
    private let session: URLSession

    private var typingTimers: [Int: Timer] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 40
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        fetchServerAndListen()
    }

    func stop() {
        isRunning = false
        isConnected = false
        currentTask?.cancel()
        currentTask = nil
    }

    private func fetchServerAndListen() {
        guard isRunning else { return }

        MessagesService.shared.fetchLongPollServer(needPts: true) { [weak self] result in
            guard let self = self, self.isRunning else { return }
            switch result {
            case .success(let info):
                self.server = info.server
                self.key = info.key
                self.ts = info.ts
                self.pts = info.pts
                if let unread = info.unreadCount {
                    DispatchQueue.main.async {
                        self.unreadCount = unread
                    }
                }
                self.listenLoop()
            case .failure(let error):
                print("[LongPoll] Server fetch failed: \(error), retrying in 5s...")
                DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                    self.fetchServerAndListen()
                }
            }
        }
    }

    private func listenLoop() {
        guard isRunning, let server = server, let key = key, let ts = ts else { return }

        // Mode: 2 (attachments) + 8 (pts) + 32 (pts) + 64 (extra) + 128 (random_id) = 234
        var urlComponents = URLComponents(string: server.hasPrefix("http") ? server : "https://\(server)")
        urlComponents?.queryItems = [
            URLQueryItem(name: "act", value: "a_check"),
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "ts", value: "\(ts)"),
            URLQueryItem(name: "wait", value: "25"),
            URLQueryItem(name: "mode", value: "234"),
            URLQueryItem(name: "version", value: "2")
        ]

        guard let url = urlComponents?.url else {
            fetchServerAndListen()
            return
        }

        currentTask = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, self.isRunning else { return }

            if let error = error {
                if (error as NSError).code == NSURLErrorCancelled { return }
                DispatchQueue.main.async { self.isConnected = false }
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                    self.listenLoop()
                }
                return
            }

            guard let data = data else {
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                    self.listenLoop()
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    DispatchQueue.main.async { self.isConnected = true }

                    if let failed = json["failed"] as? Int {
                        if failed == 1, let newTs = json["ts"] as? Int {
                            self.ts = newTs
                            self.listenLoop()
                        } else {
                            self.fetchServerAndListen()
                        }
                        return
                    }

                    if let newTs = json["ts"] as? Int {
                        self.ts = newTs
                    }
                    if let newPts = json["pts"] as? Int {
                        self.pts = newPts
                    }

                    if let updates = json["updates"] as? [[Any]] {
                        for update in updates {
                            self.handleUpdate(update)
                        }
                    }
                }
            } catch {
                print("[LongPoll] JSON parse error: \(error)")
            }

            if self.isRunning {
                self.listenLoop()
            }
        }

        currentTask?.resume()
    }

    private func handleUpdate(_ update: [Any]) {
        guard let code = update.first as? Int else { return }

        switch code {
        case 1:
            if update.count >= 4,
               let msgId = update[1] as? Int,
               let flags = update[2] as? Int,
               let peerId = update[3] as? Int {
                if (flags & 128) != 0 {
                    DispatchQueue.main.async {
                        self.events.send(.messageDeleted(id: msgId, peerId: peerId))
                    }
                }
            }

        case 4: // New Message
            // [4, message_id, flags, peer_id, timestamp, subject, text, attachments, random_id]
            if update.count >= 7,
               let msgId = update[1] as? Int,
               let flags = update[2] as? Int,
               let peerId = update[3] as? Int,
               let timestamp = update[4] as? Int,
               let text = update[6] as? String {

                let attachments = (update.count > 7 ? update[7] as? [String: Any] : nil) ?? [:]
                let fromIdStr = attachments["from"] as? String
                let fromId = fromIdStr.flatMap(Int.init) ?? peerId
                let replyToStr = attachments["reply_to"] as? String
                let replyTo = replyToStr.flatMap(Int.init)

                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                DispatchQueue.main.async {
                    self.events.send(.newMessage(
                        id: msgId,
                        flags: flags,
                        peerId: peerId,
                        date: date,
                        text: text,
                        attachments: attachments,
                        fromId: fromId,
                        replyTo: replyTo
                    ))
                }
            }

        case 5: // Edit Message
            // [5, message_id, flags, peer_id, timestamp, text, attachments]
            if update.count >= 6,
               let msgId = update[1] as? Int,
               let peerId = update[3] as? Int,
               let text = update[5] as? String {

                let attachments = (update.count > 6 ? update[6] as? [String: Any] : nil) ?? [:]
                DispatchQueue.main.async {
                    self.events.send(.editMessage(
                        id: msgId,
                        peerId: peerId,
                        text: text,
                        attachments: attachments
                    ))
                }
            }

        case 51: // Chat changed
            if update.count >= 3, let chatId = update[2] as? Int {
                DispatchQueue.main.async {
                    self.events.send(.chatUpdated(chatId: chatId))
                }
            }

        case 61: // Typing
            // [61, peer_id, user_ids]
            if update.count >= 3, let peerId = update[1] as? Int {
                let userIds: [Int]
                if let rawIds = update[2] as? [Int] {
                    userIds = rawIds
                } else if let rawId = update[2] as? Int {
                    userIds = [rawId]
                } else if let rawStr = update[2] as? String {
                    userIds = rawStr.components(separatedBy: ",").compactMap(Int.init)
                } else {
                    userIds = []
                }

                DispatchQueue.main.async {
                    self.events.send(.typing(peerId: peerId, userIds: userIds))
                }
            }

        case 80: // Unread count
            if update.count >= 2, let count = update[1] as? Int {
                DispatchQueue.main.async {
                    self.unreadCount = count
                    self.events.send(.unreadCountChanged(count: count))
                }
            }

        default:
            break
        }
    }
}
