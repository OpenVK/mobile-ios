//
//  LongPollService.swift
//  OpenVK for iOS
//

import Foundation
import UIKit

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
