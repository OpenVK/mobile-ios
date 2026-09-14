//
//  LongPollService.swift
//  OpenVK for iOS
//

import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let openvkLongPollDidReceiveEvent = Notification.Name("openvk.longPollDidReceiveEvent")
}

private struct LongPollServerResponse: Decodable {
    let key: String
    let server: String
    let ts: Int
    let pts: Int?
    let unreadCount: Int?

    private enum CodingKeys: String, CodingKey { case key, server, ts, pts, unreadCount = "unread_count" }

    init(key: String, server: String, ts: Int, pts: Int?, unreadCount: Int?) {
        self.key = key
        self.server = server
        self.ts = ts
        self.pts = pts
        self.unreadCount = unreadCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        server = try container.decode(String.self, forKey: .server)
        ts = try FlexibleInt.decode(from: container, forKey: .ts)
        pts = try? FlexibleInt.decode(from: container, forKey: .pts)
        unreadCount = try? FlexibleInt.decode(from: container, forKey: .unreadCount)
    }
}

private struct NotificationPeerContext {
    let title: String
    let avatarURL: URL?
}

final class LongPollService {
    static let shared = LongPollService()

    private let session: URLSession
    private var task: Task<Void, Never>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var isRunning = false

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration)
    }

    func start() {
        guard AuthService.shared.isAuthenticated, task == nil else { return }
        isRunning = true
        #if DEBUG
        print("[LongPoll] starting")
        #endif
        task = Task { [weak self] in
            await self?.listenLoop()
        }
    }

    func stop() {
        isRunning = false
        task?.cancel()
        task = nil
        endBackgroundTask()
    }

    func prepareForBackground() {
        guard isRunning, backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "OpenVK Long Poll") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    func resumeAfterBackground() {
        endBackgroundTask()
        if AuthService.shared.isAuthenticated {
            start()
        }
    }

    private func listenLoop() async {
        defer { task = nil }

        var server: LongPollServerResponse?
        while isRunning && !Task.isCancelled && AuthService.shared.isAuthenticated {
            do {
                if server == nil {
                    server = try await APIClient.shared.call(
                        method: "messages.getLongPollServer",
                        parameters: ["lp_version": "3", "need_pts": "1"],
                        httpMethod: "GET",
                        as: LongPollServerResponse.self
                    )
                }

                guard let currentServer = server else { continue }
                let result = try await poll(currentServer)

                if let failed = result.failed {
                    if failed == 2 || failed == 3 {
                        server = nil
                    } else if failed == 1, let nextTS = result.ts {
                        server = LongPollServerResponse(
                            key: currentServer.key,
                            server: currentServer.server,
                            ts: nextTS,
                            pts: currentServer.pts,
                            unreadCount: currentServer.unreadCount
                        )
                    }
                    continue
                }

                if let nextTS = result.ts {
                    server = LongPollServerResponse(
                        key: currentServer.key,
                        server: currentServer.server,
                        ts: nextTS,
                        pts: currentServer.pts,
                        unreadCount: currentServer.unreadCount
                    )
                }

                for event in result.updates {
                    handle(event: event)
                }
            } catch {
                guard isRunning, !Task.isCancelled else { break }
                #if DEBUG
                print("[LongPoll] error: \(error.localizedDescription). Reconnecting…")
                #endif
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                server = nil
            }
        }
    }

    private func poll(_ server: LongPollServerResponse) async throws -> LongPollResponse {
        var components = URLComponents(string: normalizedServerURL(server.server))
        components?.queryItems = [
            URLQueryItem(name: "key", value: server.key),
            URLQueryItem(name: "ts", value: String(server.ts)),
            URLQueryItem(name: "pts", value: server.pts.map(String.init)),
            URLQueryItem(name: "mode", value: "490"),
            URLQueryItem(name: "version", value: "3")
        ].filter { $0.value != nil }

        guard let url = components?.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(LongPollResponse.self, from: data)
    }

    private func normalizedServerURL(_ value: String) -> String {
        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            return value
        }
        let scheme = AppConfig.apiBaseURL.scheme ?? "https"
        return "\(scheme)://\(value)"
    }

    private func handle(event: [LongPollValue]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handle(event: event)
            }
            return
        }

        guard let type = event.first?.intValue else { return }
        let eventValues: [Any] = event.map { value in
            if let int = value.intValue { return int }
            if case .string(let string) = value { return string }
            return NSNull()
        }
        var userInfo: [String: Any] = ["type": type, "event": eventValues]
        if event.count > 1, let messageID = event[1].intValue {
            userInfo["messageID"] = messageID
        }
        if event.count > 3, let peerID = event[3].intValue {
            userInfo["peerID"] = peerID
        }
        if event.count > 5, case .string(let text) = event[5] {
            userInfo["text"] = text
        }
        if type == 61, event.count > 1, let userID = event[1].intValue {
            userInfo["userID"] = userID
        }
        if type == 62, event.count > 2 {
            if let userID = event[1].intValue { userInfo["userID"] = userID }
            if let peerID = event[2].intValue { userInfo["peerID"] = peerID }
        }
        if type == 63 || type == 64 {
            let usersIndex = event.count > 1 && event[1].intArrayValue != nil ? 1 : 2
            let peerIndex = usersIndex == 1 ? 2 : 1
            if event.count > peerIndex, let peerID = event[peerIndex].intValue {
                userInfo["peerID"] = peerID
            }
            if event.count > usersIndex { userInfo["userIDs"] = event[usersIndex].intArrayValue ?? [] }
        }
        #if DEBUG
        print("[LongPoll] received event \(type)")
        #endif
        NotificationCenter.default.post(name: .openvkLongPollDidReceiveEvent, object: nil, userInfo: userInfo)

        switch type {
        case 0:
            if let messageID = event.count > 1 ? event[1].intValue : nil {
                removeLocalNotification(messageID: messageID)
            } else {
                removeAllMessageNotifications()
            }
        case 13:
            removeAllMessageNotifications()
        case 5:
            guard let messageID = event.count > 1 ? event[1].intValue : nil else { return }
            let message = event.count > 5 ? event[5].stringValue : ""
            updateLocalNotification(messageID: messageID, message: message)
        case 4:
            let message = event.count > 5 ? event[5].stringValue : ""
            let peerID = event.count > 3 ? event[3].intValue : nil
            let messageID = event.count > 1 ? event[1].intValue : nil
            scheduleLocalNotification(
                messageID: messageID,
                message: message,
                peerID: peerID
            )
            Task { [weak self] in
                let context = await self?.notificationContext(for: peerID)
                await MainActor.run {
                    guard let self, let context else { return }
                    self.replaceLocalNotification(
                        messageID: messageID,
                        message: message,
                        peerID: peerID,
                        context: context
                    )
                }
            }
        default:
            break
        }
    }

    private func scheduleLocalNotification(
        messageID: Int?,
        message: String,
        peerID: Int?,
        context: NotificationPeerContext? = nil
    ) {
        guard UIApplication.shared.applicationState != .active else { return }

        let content = UNMutableNotificationContent()
        content.title = context?.title ?? "Новое сообщение"
        content.body = message.isEmpty ? "Вам пришло новое сообщение" : message
        content.sound = .default
        content.threadIdentifier = peerID.map { "conversation-\($0)" } ?? "messages"

        let identifier = notificationIdentifier(messageID: messageID)
        Task {
            if let avatarURL = context?.avatarURL,
               let attachment = try? await makeAttachment(from: avatarURL) {
                content.attachments = [attachment]
            }
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                #if DEBUG
                if let error {
                    print("[Notifications] failed to schedule: \(error.localizedDescription)")
                } else {
                    print("[Notifications] scheduled message notification")
                }
                #endif
            }
        }
    }

    private func updateLocalNotification(messageID: Int, message: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        removeLocalNotification(messageID: messageID)
        scheduleLocalNotification(messageID: messageID, message: message, peerID: nil)
    }

    private func replaceLocalNotification(
        messageID: Int?,
        message: String,
        peerID: Int?,
        context: NotificationPeerContext
    ) {
        guard UIApplication.shared.applicationState != .active else { return }
        if let messageID {
            removeLocalNotification(messageID: messageID)
        }
        scheduleLocalNotification(
            messageID: messageID,
            message: message,
            peerID: peerID,
            context: context
        )
    }

    private func notificationContext(for peerID: Int?) async -> NotificationPeerContext? {
        guard let peerID else { return nil }
        if let conversation = await fetchConversation(peerID: peerID) {
            return NotificationPeerContext(title: conversation.title, avatarURL: conversation.avatarURL)
        }
        return nil
    }

    private func fetchConversation(peerID: Int) async -> NotificationPeerContext? {
        do {
            let response = try await APIClient.shared.call(
                method: "messages.getConversationsById",
                parameters: [
                    "peer_ids": String(peerID),
                    "extended": "1",
                    "fields": "screen_name,photo_100,photo_200,verified"
                ],
                httpMethod: "GET",
                as: VKConversationsResponse.self
            )
            guard let item = response.items?.first else { return nil }
            let peer = item.conversation.peer
            if peer.type == "chat" || peer.id >= 2_000_000_000 {
                let settings = item.conversation.chatSettings
                return NotificationPeerContext(
                    title: settings?.title?.isEmpty == false ? settings!.title! : "Беседа",
                    avatarURL: settings?.photo100.flatMap(URL.init)
                )
            }
            if peer.id < 0, let group = response.groups?.first(where: { $0.id == abs(peer.id) }) {
                return NotificationPeerContext(
                    title: group.name ?? "Сообщество",
                    avatarURL: (group.photo200 ?? group.photo100).flatMap(URL.init)
                )
            }
            if let profile = response.profiles?.first(where: { $0.id == abs(peer.id) }) {
                let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return NotificationPeerContext(
                    title: name.isEmpty ? "Пользователь" : name,
                    avatarURL: (profile.photo200 ?? profile.photo100).flatMap(URL.init)
                )
            }
        } catch {
            #if DEBUG
            print("[Notifications] failed to load peer context: \(error.localizedDescription)")
            #endif
        }
        return nil
    }

    private func makeAttachment(from url: URL) async throws -> UNNotificationAttachment {
        let (data, _) = try await URLSession.shared.data(from: url)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("openvk-avatar-\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        try data.write(to: fileURL, options: .atomic)
        return try UNNotificationAttachment(identifier: UUID().uuidString, url: fileURL)
    }

    private func removeLocalNotification(messageID: Int) {
        let identifier = notificationIdentifier(messageID: messageID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func removeAllMessageNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let identifiers = requests.map(\.identifier).filter { $0.hasPrefix("openvk-message-") }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
        center.getDeliveredNotifications { notifications in
            let identifiers = notifications.map(\.request.identifier).filter { $0.hasPrefix("openvk-message-") }
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    private func notificationIdentifier(messageID: Int?) -> String {
        "openvk-message-\(messageID.map(String.init) ?? UUID().uuidString)"
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}

private struct LongPollResponse: Decodable {
    let failed: Int?
    let ts: Int?
    let updates: [[LongPollValue]]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        failed = try? FlexibleInt.decode(from: container, forKey: .failed)
        ts = try? FlexibleInt.decode(from: container, forKey: .ts)
        updates = (try? container.decode([[LongPollValue]].self, forKey: .updates)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case failed, ts, updates
    }
}

private enum FlexibleInt {
    static func decode<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) throws -> Int {
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let value = try? container.decode(String.self, forKey: key), let int = Int(value) { return int }
        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Expected Int or numeric String"))
    }
}

private enum LongPollValue: Decodable {
    case int(Int)
    case string(String)
    case bool(Bool)
    case object
    case array([LongPollValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) { self = .int(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if (try? container.decode([String: LongPollValue].self)) != nil { self = .object }
        else if let value = try? container.decode([LongPollValue].self) { self = .array(value) }
        else { self = .null }
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var intArrayValue: [Int]? {
        guard case .array(let values) = self else { return nil }
        return values.compactMap(\.intValue)
    }

    var stringValue: String {
        if case .string(let value) = self { return value }
        return ""
    }
}
