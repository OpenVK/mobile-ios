//
//  Message.swift
//  OpenVK for iOS
//
//  Модель сообщений.
//

import Foundation

struct Conversation: Identifiable, Hashable {
    let id: UUID
    let peer: User
    let lastMessage: String
    let lastMessageOutgoing: Bool
    let updatedAt: Date
    let unreadCount: Int
    let lastMessageId: Int

    init(id: UUID = UUID(),
         peer: User,
         lastMessage: String,
         lastMessageOutgoing: Bool = false,
         updatedAt: Date = Date(),
         unreadCount: Int = 0,
         lastMessageId: Int = 0) {
        self.id = id
        self.peer = peer
        self.lastMessage = lastMessage
        self.lastMessageOutgoing = lastMessageOutgoing
        self.updatedAt = updatedAt
        self.unreadCount = unreadCount
        self.lastMessageId = lastMessageId
    }
}

struct Message: Identifiable, Equatable {
    let id: Int
    let peerId: Int
    let fromId: Int
    let text: String
    let date: Date
    let direction: Direction

    enum Direction: Equatable { case incoming, outgoing }
}

struct VKConversationsResponse: Decodable {
    let count: Int
    let items: [VKConversationItem]
    let profiles: [VKUserProfile]?
    let groups: [VKGroupProfile]?
}

struct VKConversationItem: Decodable {
    let conversation: VKConversationInfo
    let lastMessage: VKMessageItem?
}

struct VKConversationInfo: Decodable {
    let peer: VKPeer
    let lastMessageId: Int
    let inRead: Int?
    let outRead: Int?
    let unreadCount: Int?
    let canWrite: VKCanWrite?
}

struct VKPeer: Decodable {
    let id: Int
    let type: String
    let localId: Int
}

struct VKCanWrite: Decodable {
    let allowed: Bool
    let reason: Int?
}

struct VKMessageItem: Decodable {
    let id: Int
    let peerId: Int?
    let userId: Int?
    let fromId: Int
    let date: Int
    let out: Int
    let body: String?
    let text: String?
    let emoji: Bool?
}

struct VKMessageHistoryResponse: Decodable {
    let count: Int
    let items: [VKMessageItem]
    let profiles: [VKUserProfile]?
    let groups: [VKGroupProfile]?
}

struct VKSendMessageResponse: Decodable {
    let response: Int?
}
