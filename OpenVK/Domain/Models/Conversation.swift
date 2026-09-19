//
//  Conversation.swift
//  OpenVK for iOS
//

import Foundation

struct Conversation: Identifiable, Hashable {
    let id: Int
    let peer: User
    let lastMessage: String
    let lastMessageAuthorName: String?
    let lastMessageOutgoing: Bool
    let updatedAt: Date
    let unreadCount: Int
    let lastMessageId: Int

    var isChat: Bool
    var isGroup: Bool { peer.isGroup == true }
}

struct ConversationsPage {
    let totalCount: Int
    let conversations: [Conversation]
}

struct VKConversationsResponse: Decodable {
    let count: Int?
    let items: [VKConversationItem]?
    let profiles: [VKUserProfile]?
    let groups: [VKGroupProfile]?
}

struct VKConversationItem: Decodable {
    let conversation: VKConversationInfo
    let lastMessage: VKConversationMessage?

    private enum CodingKeys: String, CodingKey {
        case conversation
        case lastMessage = "last_message"
        case lastMessageCamel = "lastMessage"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let nested = try? container.decode(VKConversationInfo.self, forKey: .conversation) {
            conversation = nested
        } else {
            conversation = try VKConversationInfo(from: decoder)
        }
        lastMessage = (try? container.decode(VKConversationMessage.self, forKey: .lastMessage))
            ?? (try? container.decode(VKConversationMessage.self, forKey: .lastMessageCamel))
    }
}

struct VKConversationInfo: Decodable {
    let peer: VKConversationPeer
    let lastMessageId: Int?
    let unreadCount: Int?
    let chatSettings: VKChatSettings?
}

struct VKConversationPeer: Decodable {
    let id: Int
    let type: String?
}

struct VKChatSettings: Decodable {
    let title: String?
    let photo100: String?
}

struct VKConversationMessage: Decodable {
    let id: Int?
    let fromId: Int?
    let date: Int?
    let out: Int?
    let body: String?
    let text: String?
    let attachments: [VKConversationAttachment]?
}

struct VKConversationAttachment: Decodable {
    let type: String?
}

struct VKMessagesHistoryResponse: Decodable {
    let count: Int?
    let items: [VKHistoryMessage]?
    let profiles: [VKUserProfile]?
}

struct VKHistoryMessage: Decodable {
    let id: Int?
    let fromId: Int?
    let date: Int?
    let out: Int?
    let body: String?
    let text: String?
    let attachments: [VKConversationAttachment]?
    let deleted: Int?
    let readState: Int?
}

struct MessagesPage {
    let count: Int
    let messages: [ChatMessage]
}

struct ChatMessage: Identifiable, Hashable {
    let id: Int
    let text: String
    let date: Date
    let isOutgoing: Bool
    let senderName: String?
    let attachmentTypes: [String]
    let isDeleted: Bool
    let deliveryStatus: MessageDeliveryStatus?

    init(message: VKHistoryMessage, profiles: [VKUserProfile]) {
        let senderID = message.fromId ?? 0
        id = message.id ?? Int.random(in: 1...Int.max)
        let body = message.body ?? message.text ?? ""
        let attachments = message.attachments ?? []
        text = body.isEmpty ? attachments.map { Self.attachmentTitle($0.type) }.joined(separator: " ") : body
        date = Date(timeIntervalSince1970: TimeInterval(message.date ?? 0))
        isOutgoing = message.out == 1 || senderID == AuthService.shared.currentUser?.uid
        let profile = profiles.first(where: { $0.id == abs(senderID) })
        let name = [profile?.firstName, profile?.lastName].compactMap { $0 }.joined(separator: " ")
        senderName = name.isEmpty ? nil : name
        attachmentTypes = attachments.compactMap(\.type)
        isDeleted = message.deleted == 1
        deliveryStatus = isOutgoing ? ((message.readState ?? 0) == 1 ? .read : .unread) : nil
    }

    private init(
        id: Int,
        text: String,
        date: Date,
        isOutgoing: Bool,
        senderName: String?,
        attachmentTypes: [String],
        isDeleted: Bool,
        deliveryStatus: MessageDeliveryStatus?
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.isOutgoing = isOutgoing
        self.senderName = senderName
        self.attachmentTypes = attachmentTypes
        self.isDeleted = isDeleted
        self.deliveryStatus = deliveryStatus
    }

    static func pending(text: String) -> ChatMessage {
        ChatMessage(
            id: -Int.random(in: 1...Int.max),
            text: text,
            date: Date(),
            isOutgoing: true,
            senderName: nil,
            attachmentTypes: [],
            isDeleted: false,
            deliveryStatus: .sending
        )
    }

    func updatingDeliveryStatus(_ status: MessageDeliveryStatus, id: Int? = nil) -> ChatMessage {
        ChatMessage(
            id: id ?? self.id,
            text: text,
            date: date,
            isOutgoing: isOutgoing,
            senderName: senderName,
            attachmentTypes: attachmentTypes,
            isDeleted: isDeleted,
            deliveryStatus: status
        )
    }

    private static func attachmentTitle(_ type: String?) -> String {
        switch type?.lowercased() {
        case "photo": return "[Фотография]"
        case "video": return "[Видео]"
        case "audio": return "[Аудиозапись]"
        case "doc", "document": return "[Документ]"
        case "wall": return "[Запись]"
        case "sticker": return "[Стикер]"
        case "gift": return "[Подарок]"
        default: return "[Вложение]"
        }
    }
}

enum MessageDeliveryStatus: Hashable {
    case sending
    case unread
    case read
    case failed
}
