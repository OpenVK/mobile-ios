//
//  OpenVKTests.swift
//  OpenVK for iOS
//
//  Created by nika on 11.07.2026.
//

import XCTest
@testable import OpenVK

class OpenVKTests: XCTestCase {

    func testFeedMappingOwnWallPost() throws {
        let json = """
        {
          "items": [
            {
              "id": 100,
              "from_id": 2,
              "owner_id": 2,
              "date": 1700000000,
              "text": "свой пост",
              "post_source": {"type": "api", "platform": "iphone"},
              "likes": {"count": 5, "user_likes": 0},
              "comments": {"count": 1},
              "reposts": {"count": 0}
            }
          ],
          "profiles": [
            {"id": 2, "first_name": "Иван", "last_name": "Петров", "screen_name": "ivan", "photo_100": "https://example.com/i.png"}
          ],
          "groups": []
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(VKFeedResponse.self, from: json)
        let posts = FeedService.shared.mapVKFeed(response)

        XCTAssertEqual(posts.count, 1)
        let post = posts[0]
        XCTAssertEqual(post.author.uid, 2)
        XCTAssertEqual(post.ownerID, 2)
        XCTAssertNil(post.wallOwner)
        XCTAssertFalse(post.isOnAlienWall)
        XCTAssertEqual(post.platform, "iphone")
        XCTAssertEqual(post.timeAgo, OpenVKDateFormatter.formatRelative(Date(timeIntervalSince1970: 1700000000)))
    }

    func testFeedMappingAlienWallPost() throws {
        let json = """
        {
          "items": [
            {
              "id": 101,
              "from_id": 2,
              "owner_id": 3,
              "date": 1700000000,
              "text": "привет на чужой стене",
              "post_source": {"type": "api", "platform": "android"},
              "likes": 0,
              "comments": 0,
              "reposts": 0
            }
          ],
          "profiles": [
            {"id": 2, "first_name": "Иван", "last_name": "Петров", "screen_name": "ivan", "photo_100": "https://example.com/i.png"},
            {"id": 3, "first_name": "Мария", "last_name": "Смирнова", "screen_name": "maria", "photo_100": "https://example.com/m.png"}
          ],
          "groups": []
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(VKFeedResponse.self, from: json)
        let posts = FeedService.shared.mapVKFeed(response)

        XCTAssertEqual(posts.count, 1)
        let post = posts[0]
        XCTAssertEqual(post.author.uid, 2)
        XCTAssertEqual(post.author.displayName, "Иван Петров")
        XCTAssertEqual(post.ownerID, 3)
        XCTAssertEqual(post.wallOwner?.uid, 3)
        XCTAssertEqual(post.wallOwner?.displayName, "Мария Смирнова")
        XCTAssertTrue(post.isOnAlienWall)
        XCTAssertEqual(post.platform, "android")
    }

    func testFeedMappingGroupAuthorAndPlatformIcon() throws {
        let json = """
        {
          "items": [
            {
              "id": 102,
              "from_id": -5,
              "owner_id": -5,
              "date": 1700000000,
              "text": "пост от сообщества",
              "post_source": {"type": "api", "platform": "wphone"},
              "likes": 1,
              "comments": 0,
              "reposts": 0
            }
          ],
          "profiles": [],
          "groups": [
            {"id": 5, "name": "OpenVK", "screen_name": "openvk", "photo_100": "https://example.com/o.png"}
          ]
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(VKFeedResponse.self, from: json)
        let posts = FeedService.shared.mapVKFeed(response)

        XCTAssertEqual(posts.count, 1)
        let post = posts[0]
        XCTAssertEqual(post.author.uid, -5)
        XCTAssertEqual(post.author.isGroup, true)
        XCTAssertNil(post.wallOwner)
        XCTAssertEqual(post.platform, "wphone")
        XCTAssertEqual(PostPlatform(rawValue: "android")?.iconName, "phone.fill")
        XCTAssertEqual(PostPlatform(rawValue: "wphone")?.iconName, "ipad")
        XCTAssertEqual(PostPlatform(rawValue: "wphone")?.assetName, "wphone")
        XCTAssertEqual(PostPlatform(rawValue: "api")?.iconName, "chevron.left.forwardslash.chevron.right")
        XCTAssertEqual(PostPlatform(rawValue: "iphone")?.iconName, "applelogo")
        XCTAssertEqual(PostPlatform(rawValue: "web")?.iconName, "globe")
    }

    func testFeedMappingRepostPlatform() throws {
        let json = """
        {
          "items": [
            {
              "id": 103,
              "from_id": 2,
              "owner_id": 2,
              "date": 1700000000,
              "text": "репост",
              "post_source": {"type": "api", "platform": "android"},
              "copy_history": [
                {
                  "id": 7,
                  "from_id": 3,
                  "owner_id": 3,
                  "date": 1699999000,
                  "text": "оригинал",
                  "post_source": {"type": "api", "platform": "iphone"}
                }
              ]
            }
          ],
          "profiles": [
            {"id": 2, "first_name": "Иван", "last_name": "Петров", "screen_name": "ivan", "photo_100": "https://example.com/i.png"},
            {"id": 3, "first_name": "Мария", "last_name": "Смирнова", "screen_name": "maria", "photo_100": "https://example.com/m.png"}
          ],
          "groups": []
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(VKFeedResponse.self, from: json)
        let posts = FeedService.shared.mapVKFeed(response)

        XCTAssertEqual(posts.count, 1)
        let post = posts[0]
        XCTAssertEqual(post.platform, "android")
        XCTAssertEqual(post.copyHistory.count, 1)
        XCTAssertEqual(post.copyHistory[0].platform, "iphone")
    }

    func testLastSeenPlatformMapping() throws {
        let json = """
        [
          {"id": 1, "first_name": "А", "last_name": "Б", "online": 1, "last_seen": {"time": 1700000000, "platform": 2}},
          {"id": 2, "first_name": "В", "last_name": "Г", "online": 1, "last_seen": {"time": 1700000000, "platform": 4}},
          {"id": 3, "first_name": "Д", "last_name": "Е", "online": 1, "last_seen": {"time": 1700000000, "platform": 7}},
          {"id": 4, "first_name": "Ж", "last_name": "З", "online": 1, "last_seen": {"time": 1700000000, "platform": 1}}
        ]
        """.data(using: .utf8)!
        let users = try JSONDecoder().decode([VKUserProfile].self, from: json)

        XCTAssertEqual(users[0].lastSeen?.platformName, "iphone")
        XCTAssertEqual(users[1].lastSeen?.platformName, "android")
        XCTAssertNil(users[2].lastSeen?.platformName)
        XCTAssertNil(users[3].lastSeen?.platformName)
    }

    private func offlineMessages(_ ids: ClosedRange<Int>) throws -> [ChatMessage] {
        try ids.map { id in
            let data = Data("{\"id\":\(id),\"from_id\":2,\"date\":1700000000,\"text\":\"message \(id)\"}".utf8)
            return ChatMessage(message: try JSONDecoder().decode(VKHistoryMessage.self, from: data), profiles: [])
        }
    }

    func testOfflineHistoryRestoresAroundAnUncachedAnchor() throws {
        let messages = try offlineMessages(1...100)
        let page = try XCTUnwrap(OfflineMessageHistory.page(messages: messages, offset: -20, count: 40, startMessageID: 50, reverse: false))
        XCTAssertEqual(page.messages.map(\.id), Array(31...70))
        XCTAssertEqual(page.count, 70)
    }

    func testOfflineHistoryStopsAtBothLocalBoundaries() throws {
        let messages = try offlineMessages(1...100)
        let older = try XCTUnwrap(OfflineMessageHistory.page(messages: messages, offset: 1, count: 40, startMessageID: 10, reverse: false))
        XCTAssertEqual(older.messages.map(\.id), Array(1...9))
        XCTAssertEqual(older.count, older.messages.count + 1)
        let newer = try XCTUnwrap(OfflineMessageHistory.page(messages: messages, offset: 1, count: 40, startMessageID: 90, reverse: true))
        XCTAssertEqual(newer.messages.map(\.id), Array(91...100))
        XCTAssertEqual(newer.count, newer.messages.count + 1)
        let end = try XCTUnwrap(OfflineMessageHistory.page(messages: messages, offset: 1, count: 40, startMessageID: 100, reverse: true))
        XCTAssertTrue(end.messages.isEmpty)
        XCTAssertEqual(end.count, 1)
    }

    func testOfflineHistoryDoesNotInventMissingAnchor() throws {
        let messages = try offlineMessages(1...10)
        XCTAssertNil(OfflineMessageHistory.page(messages: messages, offset: -20, count: 40, startMessageID: 500, reverse: false))
        let page = try XCTUnwrap(OfflineMessageHistory.page(messages: messages, offset: 0, count: 40, startMessageID: nil, reverse: false))
        XCTAssertEqual(page.messages.map(\.id), Array(1...10))
    }

    func testOfflineFallbackDoesNotHideAuthorizationErrors() {
        XCTAssertTrue(MessagesService.isConnectionFailure(APIError.transport(URLError(.notConnectedToInternet))))
        XCTAssertTrue(MessagesService.isConnectionFailure(APIError.http(503)))
        XCTAssertFalse(MessagesService.isConnectionFailure(APIError.vk(code: 5, message: "Expired token")))
        XCTAssertFalse(MessagesService.isConnectionFailure(APIError.vk(code: 15, message: "Access denied")))
        XCTAssertFalse(MessagesService.isConnectionFailure(APIError.http(403)))
    }

    func testLongPollConnectionTitles() {
        XCTAssertEqual(LongPollConnectionState.connecting.title, "Обновление…")
        XCTAssertEqual(LongPollConnectionState.offline.title, "Подключение…")
        XCTAssertEqual(LongPollConnectionState.connected.title, "Сообщения")
        XCTAssertNil(LongPollConnectionState.connected.chatSubtitle)
    }

    func testPerformanceExample() throws {
        self.measure {
        }
    }
}
