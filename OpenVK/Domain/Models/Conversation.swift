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
    let lastMessageReadState: Int?

    var isChat: Bool
    var isChatMember: Bool = true
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
    let canWrite: VKConversationCanWrite?
}

struct VKConversationPeer: Decodable {
    let id: Int
    let type: String?
}

struct VKChatSettings: Decodable {
    let title: String?
    let photo100: String?
    let state: String?
}

struct VKConversationCanWrite: Decodable {
    let allowed: Bool?
    let reason: Int?
}

struct VKConversationMessage: Decodable {
    let id: Int?
    let fromId: Int?
    let date: Int?
    let out: Int?
    let body: String?
    let text: String?
    let attachments: [VKConversationAttachment]?
    let readState: Int?
}

struct VKConversationAttachment: Decodable {
    let type: String?
    let sticker: VKSticker?
    let photo: VKMessagePhoto?
}

struct VKMessagePhoto: Decodable {
    let id: Int?
    let ownerId: Int?
    let sizes: [VKPhotoSize]?

    var chatPhoto: ChatPhoto? {
        let preferredTypes = ["w", "z", "y", "x", "r", "q"]
        let urlString = preferredTypes.compactMap { preferredType in
            sizes?.first(where: { $0.type == preferredType })?.url
                ?? sizes?.first(where: { $0.type == preferredType })?.src
        }.first ?? sizes?.last?.url ?? sizes?.last?.src
        guard let urlString, let url = URL(string: urlString) else { return nil }
        return ChatPhoto(id: id, ownerID: ownerId, url: url)
    }
}

struct ChatPhoto: Identifiable, Hashable {
    let id: String
    let url: URL

    init(id: Int?, ownerID: Int?, url: URL) {
        self.id = "\(ownerID ?? 0)_\(id ?? 0)_\(url.absoluteString)"
        self.url = url
    }
}

struct VKSticker: Decodable {
    let id: Int?
    let stickerID: Int?
    let productID: Int?
    let emoji: String?
    let photo128: String?
    let photo256: String?
    let photo512: String?
    let images: [VKStickerImage]?
    let animationURLString: String?
    let animations: [VKStickerAnimation]?

    private enum CodingKeys: String, CodingKey {
        case id
        case stickerID = "sticker_id"
        case productID = "product_id"
        case emoji
        case photo128 = "photo_128"
        case photo256 = "photo_256"
        case photo512 = "photo_512"
        case images
        case animationURLString = "animation_url"
        case animations
    }

    var imageURL: URL? {
        let imageFromList = images?.first(where: { $0.width >= 256 })?.url
            ?? images?.last?.url
        return [photo256, photo512, photo128, imageFromList]
            .compactMap { $0 }
            .compactMap(URL.init(string:))
            .first
    }

    var animationURL: URL? {
        [animationURLString, animations?.first?.url]
            .compactMap { $0 }
            .compactMap(URL.init(string:))
            .first
    }

    var identifier: Int? { stickerID ?? id }

    var thumbnailURL: URL? {
        let imageFromList = images?
            .sorted { abs($0.width - 128) < abs($1.width - 128) }
            .first?
            .url
        return [imageFromList, photo128, photo256, photo512]
            .compactMap { $0 }
            .compactMap(URL.init(string:))
            .first
    }
}

struct VKStickerImage: Decodable {
    let url: String?
    let width: Int
}

struct VKStickerAnimation: Decodable {
    let url: String?
}

struct VKStickerPack: Decodable, Identifiable {
    let id: Int
    let name: String?
    let title: String?
    let photo128: String?
    let stickers: [VKSticker]?

    private enum CodingKeys: String, CodingKey {
        case id, name, title, stickers
        case photo128 = "photo_128"
    }

    var displayName: String { name ?? title ?? "Стикерпаки" }
    var coverURL: URL? { stickers?.first?.thumbnailURL ?? URL(string: photo128 ?? "") }
}

struct VKStickerPacksResponse: Decodable {
    let count: Int?
    let items: [VKStickerPack]?
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
    let action: VKMessageAction?
    let actionMid: Int?
}

struct VKMessageAction: Decodable {
    let type: String?
    let memberId: Int?
    let text: String?
    let memberName: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case memberId = "member_id"
        case memberIdCamel = "memberId"
        case text
        case memberName = "member_name"
        case memberNameCamel = "memberName"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try? container.decode(String.self, forKey: .type)
        text = try? container.decode(String.self, forKey: .text)
        memberName = (try? container.decode(String.self, forKey: .memberName))
            ?? (try? container.decode(String.self, forKey: .memberNameCamel))
        memberId = Self.decodeID(from: container, key: .memberId)
            ?? Self.decodeID(from: container, key: .memberIdCamel)
    }

    private static func decodeID(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Int? {
        (try? container.decode(Int.self, forKey: key))
            ?? (try? container.decode(String.self, forKey: key)).flatMap(Int.init)
    }
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
    let senderID: Int
    let senderName: String?
    let senderAvatarURL: URL?
    let attachmentTypes: [String]
    let stickerURL: URL?
    let stickerAnimationURL: URL?
    let photos: [ChatPhoto]
    let systemEventText: String?
    let isDeleted: Bool
    let deliveryStatus: MessageDeliveryStatus?
    let endsChatParticipation: Bool

    init(message: VKHistoryMessage, profiles: [VKUserProfile]) {
        let senderID = message.fromId ?? 0
        id = message.id ?? Int.random(in: 1...Int.max)
        let body = message.body ?? message.text ?? ""
        let attachments = message.attachments ?? []
        let photos = attachments.compactMap { $0.photo?.chatPhoto }
        text = body.isEmpty && !photos.isEmpty
            ? ""
            : (body.isEmpty ? attachments.map { Self.attachmentTitle($0.type) }.joined(separator: " ") : body)
        date = Date(timeIntervalSince1970: TimeInterval(message.date ?? 0))
        isOutgoing = message.out == 1 || senderID == AuthService.shared.currentUser?.uid
        self.senderID = senderID
        let profile = profiles.first(where: { $0.id == abs(senderID) })
        let name = [profile?.firstName, profile?.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        senderName = name.isEmpty ? nil : name
        senderAvatarURL = (profile?.photo200 ?? profile?.photo100).flatMap(URL.init)
        attachmentTypes = attachments.compactMap(\.type)
        self.photos = photos
        systemEventText = Self.systemEventText(
            action: message.action,
            actionMemberID: message.actionMid,
            actorID: senderID,
            actorName: name.isEmpty ? "Пользователь" : name,
            profiles: profiles
        )
        let actionType = message.action?.type?.lowercased()
        endsChatParticipation = actionType == "chat_kick_user"
            && message.action?.memberId == AuthService.shared.currentUser?.uid
        stickerURL = body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.count == 1
            ? attachments.first?.sticker?.imageURL
            : nil
        stickerAnimationURL = body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.count == 1
            ? attachments.first?.sticker?.animationURL
            : nil
        isDeleted = message.deleted == 1
        deliveryStatus = isOutgoing ? ((message.readState ?? 0) == 1 ? .read : .unread) : nil
    }

    private init(
        id: Int,
        text: String,
        date: Date,
        isOutgoing: Bool,
        senderID: Int,
        senderName: String?,
        senderAvatarURL: URL?,
        attachmentTypes: [String],
        stickerURL: URL?,
        stickerAnimationURL: URL?,
        photos: [ChatPhoto],
        systemEventText: String?,
        isDeleted: Bool,
        deliveryStatus: MessageDeliveryStatus?,
        endsChatParticipation: Bool = false
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.isOutgoing = isOutgoing
        self.senderID = senderID
        self.senderName = senderName
        self.senderAvatarURL = senderAvatarURL
        self.attachmentTypes = attachmentTypes
        self.stickerURL = stickerURL
        self.stickerAnimationURL = stickerAnimationURL
        self.photos = photos
        self.systemEventText = systemEventText
        self.isDeleted = isDeleted
        self.deliveryStatus = deliveryStatus
        self.endsChatParticipation = endsChatParticipation
    }

    static func pending(text: String) -> ChatMessage {
        ChatMessage(
            id: -Int.random(in: 1...Int.max),
            text: text,
            date: Date(),
            isOutgoing: true,
            senderID: AuthService.shared.currentUser?.uid ?? 0,
            senderName: nil,
            senderAvatarURL: nil,
            attachmentTypes: [],
            stickerURL: nil,
            stickerAnimationURL: nil,
            photos: [],
            systemEventText: nil,
            isDeleted: false,
            deliveryStatus: .sending
        )
    }

    static func pending(sticker: VKSticker) -> ChatMessage {
        ChatMessage(
            id: -Int.random(in: 1...Int.max),
            text: "",
            date: Date(),
            isOutgoing: true,
            senderID: AuthService.shared.currentUser?.uid ?? 0,
            senderName: nil,
            senderAvatarURL: nil,
            attachmentTypes: ["sticker"],
            stickerURL: sticker.imageURL,
            stickerAnimationURL: sticker.animationURL,
            photos: [],
            systemEventText: nil,
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
            senderID: senderID,
            senderName: senderName,
            senderAvatarURL: senderAvatarURL,
            attachmentTypes: attachmentTypes,
            stickerURL: stickerURL,
            stickerAnimationURL: stickerAnimationURL,
            photos: photos,
            systemEventText: systemEventText,
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

    private static func systemEventText(
        action: VKMessageAction?,
        actionMemberID: Int?,
        actorID: Int,
        actorName: String,
        profiles: [VKUserProfile]
    ) -> String? {
        guard let actionType = action?.type?.lowercased() else { return nil }
        let memberID = action?.memberId ?? actionMemberID
        let memberNameFromProfile = memberID.flatMap { id in
            let profile = profiles.first(where: { $0.id == abs(id) })
            let name = [profile?.firstName, profile?.lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return name.isEmpty ? nil : name
        }
        let actionMemberName = action?.memberName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let memberName = (actionMemberName?.isEmpty == false ? actionMemberName : nil)
            ?? memberNameFromProfile
            ?? memberID.map { "id\(abs($0))" }
            ?? "пользователя"

        switch actionType {
        case "chat_invite_user", "chat_invite_user_by_link":
            return "\(actorName) пригласил(а) \(memberName)"
        case "chat_kick_user":
            if memberID == AuthService.shared.currentUser?.uid {
                return actorID == AuthService.shared.currentUser?.uid
                    ? "Вы покинули беседу"
                    : "Вас исключил из беседы \(actorName)"
            }
            if memberID == actorID {
                return "\(actorName) покинул(а) беседу"
            }
            return "\(actorName) исключил(а) \(memberName)"
        case "chat_promote_user", "chat_user_promote", "chat_admin_add", "chat_set_admin", "chat_moderator_add":
            return "\(actorName) назначил(а) \(memberName) администратором"
        case "chat_demote_user", "chat_user_demote", "chat_admin_remove", "chat_remove_admin", "chat_moderator_remove":
            return "\(actorName) снял(а) \(memberName) с должности администратора"
        case "chat_title_update":
            return "\(actorName) изменил(а) название беседы"
        case "chat_photo_update":
            return "\(actorName) обновил(а) фото беседы"
        case "chat_photo_remove":
            return "\(actorName) удалил(а) фото беседы"
        case "chat_create":
            return "\(actorName) создал(а) беседу"
        case "chat_pin_message":
            return "\(actorName) закрепил(а) сообщение"
        case "chat_unpin_message":
            return "\(actorName) открепил(а) сообщение"
        default:
            let text = action?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            return text?.isEmpty == false ? text : "Системное сообщение"
        }
    }
}

enum MessageDeliveryStatus: Hashable {
    case sending
    case unread
    case read
    case failed
}
