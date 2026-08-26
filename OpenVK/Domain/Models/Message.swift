//
//  Message.swift
//  OpenVK for iOS
//
//  Модели диалогов.
//

import Foundation

enum PeerType: String, Codable, Hashable {
    case user
    case chat
    case group
}

struct Peer: Identifiable, Hashable, Equatable {
    let id: Int
    let type: PeerType
    let title: String
    let avatarURL: URL?
    let isOnline: Bool?
    let onlinePlatform: String?
    let lastSeen: String?
    let membersCount: Int?
    let isOfficial: Bool?
    let user: User?
    let community: Community?

    init(
        id: Int,
        type: PeerType,
        title: String,
        avatarURL: URL? = nil,
        isOnline: Bool? = nil,
        onlinePlatform: String? = nil,
        lastSeen: String? = nil,
        membersCount: Int? = nil,
        isOfficial: Bool? = nil,
        user: User? = nil,
        community: Community? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.avatarURL = avatarURL
        self.isOnline = isOnline
        self.onlinePlatform = onlinePlatform
        self.lastSeen = lastSeen
        self.membersCount = membersCount
        self.isOfficial = isOfficial
        self.user = user
        self.community = community
    }

    static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
    }

    var uid: Int? { id }
    var displayName: String { title }
    var username: String {
        user?.username ?? (type == .group ? "club\(abs(id))" : (type == .chat ? "chat\(id > 2000000000 ? id - 2000000000 : id)" : "id\(id)"))
    }

    func toUser() -> User {
        if let u = user { return u }
        return User(
            uid: id,
            username: username,
            displayName: title,
            avatarURL: avatarURL,
            isOnline: isOnline ?? false,
            onlinePlatform: onlinePlatform,
            lastSeen: lastSeen,
            isGroup: type == .group,
            isOfficial: isOfficial ?? false
        )
    }
}

struct ChatACL: Hashable, Decodable {
    let canInvite: Bool?
    let canChangeInfo: Bool?
    let canChangePin: Bool?
    let canPromoteUsers: Bool?
    let canSeeInviteLink: Bool?
    let canChangeInviteLink: Bool?
    let canModerate: Bool?
    let canCopyChat: Bool?

    enum CodingKeys: String, CodingKey {
        case canInvite = "can_invite"
        case canChangeInfo = "can_change_info"
        case canChangePin = "can_change_pin"
        case canPromoteUsers = "can_promote_users"
        case canSeeInviteLink = "can_see_invite_link"
        case canChangeInviteLink = "can_change_invite_link"
        case canModerate = "can_moderate"
        case canCopyChat = "can_copy_chat"
    }
}

struct ChatSettings: Hashable {
    let id: Int
    let title: String
    let membersCount: Int
    let adminId: Int
    let photoURL: URL?
    let acl: ChatACL?
    let pinnedMessage: Message?
}

struct ChatMember: Identifiable, Hashable {
    var id: Int { userId }
    let userId: Int
    let invitedBy: Int?
    let joinDate: Date?
    let isAdmin: Bool
    let canKick: Bool
    let user: User?
}

struct Conversation: Identifiable, Hashable {
    let id: UUID
    let peer: Peer
    let lastMessage: String
    let lastMessageOutgoing: Bool
    let updatedAt: Date
    let unreadCount: Int
    let lastMessageId: Int
    let inRead: Int
    let outRead: Int
    let chatSettings: ChatSettings?
    let isImportant: Bool
    let isAnswered: Bool
    let isMuted: Bool

    init(
        id: UUID = UUID(),
        peer: Peer,
        lastMessage: String,
        lastMessageOutgoing: Bool = false,
        updatedAt: Date = Date(),
        unreadCount: Int = 0,
        lastMessageId: Int = 0,
        inRead: Int = 0,
        outRead: Int = 0,
        chatSettings: ChatSettings? = nil,
        isImportant: Bool = false,
        isAnswered: Bool = false,
        isMuted: Bool = false
    ) {
        self.id = id
        self.peer = peer
        self.lastMessage = lastMessage
        self.lastMessageOutgoing = lastMessageOutgoing
        self.updatedAt = updatedAt
        self.unreadCount = unreadCount
        self.lastMessageId = lastMessageId
        self.inRead = inRead
        self.outRead = outRead
        self.chatSettings = chatSettings
        self.isImportant = isImportant
        self.isAnswered = isAnswered
        self.isMuted = isMuted
    }

    init(
        id: UUID = UUID(),
        peer: User,
        lastMessage: String,
        lastMessageOutgoing: Bool = false,
        updatedAt: Date = Date(),
        unreadCount: Int = 0,
        lastMessageId: Int = 0
    ) {
        let peerModel = Peer(
            id: peer.uid ?? 0,
            type: PeerType.user,
            title: peer.displayName,
            avatarURL: peer.avatarURL,
            isOnline: peer.isOnline,
            onlinePlatform: peer.onlinePlatform,
            lastSeen: peer.lastSeen,
            isOfficial: peer.isOfficial,
            user: peer
        )
        self.init(
            id: id,
            peer: peerModel,
            lastMessage: lastMessage,
            lastMessageOutgoing: lastMessageOutgoing,
            updatedAt: updatedAt,
            unreadCount: unreadCount,
            lastMessageId: lastMessageId
        )
    }
}

struct Sticker: Identifiable, Hashable, Codable {
    let id: Int
    let packId: Int
    let imageURL: URL
    let width: Int
    let height: Int
}

struct StickerPack: Identifiable, Hashable {
    let id: Int
    let title: String
    let author: String?
    let description: String?
    let iconURL: URL?
    let isPurchased: Bool
    let isFree: Bool
    let price: Int
    let stickers: [Sticker]
}

enum MessageClusterPosition: Equatable, Hashable {
    case single
    case top
    case middle
    case bottom
}

struct Message: Identifiable, Equatable, Hashable {
    let id: Int
    let peerId: Int
    let fromId: Int
    let text: String
    let date: Date
    let direction: Direction
    let isRead: Bool
    let attachments: [Attachment]
    let replyMessage: MessageReply?
    let forwardMessages: [MessageReply]
    let isPinned: Bool
    let isImportant: Bool
    let isDeleted: Bool
    let isEdited: Bool
    let sticker: Sticker?
    let senderName: String?
    let senderAvatarURL: URL?
    let reaction: String?

    enum Direction: Equatable, Hashable {
        case incoming
        case outgoing
    }

    init(
        id: Int,
        peerId: Int,
        fromId: Int,
        text: String,
        date: Date,
        direction: Direction,
        isRead: Bool = false,
        attachments: [Attachment] = [],
        replyMessage: MessageReply? = nil,
        forwardMessages: [MessageReply] = [],
        isPinned: Bool = false,
        isImportant: Bool = false,
        isDeleted: Bool = false,
        isEdited: Bool = false,
        sticker: Sticker? = nil,
        senderName: String? = nil,
        senderAvatarURL: URL? = nil,
        reaction: String? = nil
    ) {
        self.id = id
        self.peerId = peerId
        self.fromId = fromId
        self.text = text
        self.date = date
        self.direction = direction
        self.isRead = isRead
        self.attachments = attachments
        self.replyMessage = replyMessage
        self.forwardMessages = forwardMessages
        self.isPinned = isPinned
        self.isImportant = isImportant
        self.isDeleted = isDeleted
        self.isEdited = isEdited
        self.sticker = sticker
        self.senderName = senderName
        self.senderAvatarURL = senderAvatarURL
        self.reaction = reaction
    }
}

struct MessageReply: Identifiable, Equatable, Hashable {
    let id: Int
    let fromId: Int
    let senderName: String
    let text: String
    let attachments: [Attachment]
    let date: Date?

    init(
        id: Int,
        fromId: Int,
        senderName: String,
        text: String,
        attachments: [Attachment] = [],
        date: Date? = nil
    ) {
        self.id = id
        self.fromId = fromId
        self.senderName = senderName
        self.text = text
        self.attachments = attachments
        self.date = date
    }
}

extension KeyedDecodingContainer {
    func decodeSafeInt(forKey key: K) -> Int? {
        if let intVal = try? decode(Int.self, forKey: key) {
            return intVal
        }
        if let strVal = try? decode(String.self, forKey: key), let intVal = Int(strVal) {
            return intVal
        }
        if let doubleVal = try? decode(Double.self, forKey: key) {
            return Int(doubleVal)
        }
        return nil
    }

    func decodeSafeBool(forKey key: K) -> Bool? {
        if let boolVal = try? decode(Bool.self, forKey: key) {
            return boolVal
        }
        if let intVal = try? decode(Int.self, forKey: key) {
            return intVal != 0
        }
        if let strVal = try? decode(String.self, forKey: key) {
            return strVal == "1" || strVal.lowercased() == "true"
        }
        return nil
    }

    func decodeSafeString(forKey key: K) -> String? {
        if let strVal = try? decode(String.self, forKey: key) {
            return strVal
        }
        if let intVal = try? decode(Int.self, forKey: key) {
            return String(intVal)
        }
        return nil
    }
}

struct VKConversationsResponse: Decodable {
    let count: Int?
    let unreadCount: Int?
    let items: [VKIMConversationItem]?
    let profiles: [VKUserProfile]?
    let groups: [VKGroupProfile]?
    let chats: [VKIMChatInfoItem]?

    enum CodingKeys: String, CodingKey {
        case count
        case unreadCount
        case items
        case profiles
        case groups
        case chats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = container.decodeSafeInt(forKey: .count)
        unreadCount = container.decodeSafeInt(forKey: .unreadCount)
        items = try? container.decode([VKIMConversationItem].self, forKey: .items)
        profiles = try? container.decode([VKUserProfile].self, forKey: .profiles)
        groups = try? container.decode([VKGroupProfile].self, forKey: .groups)
        chats = try? container.decode([VKIMChatInfoItem].self, forKey: .chats)
    }
}

struct VKIMConversationItem: Decodable {
    let conversation: VKIMConversationInfo?
    let lastMessage: VKIMMessageItem?

    enum CodingKeys: String, CodingKey {
        case conversation
        case lastMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversation = try? container.decode(VKIMConversationInfo.self, forKey: .conversation)
        lastMessage = try? container.decode(VKIMMessageItem.self, forKey: .lastMessage)
    }
}

struct VKIMConversationInfo: Decodable {
    let peer: VKPeer?
    let lastMessageId: Int?
    let inRead: Int?
    let outRead: Int?
    let unreadCount: Int?
    let canWrite: VKCanWrite?
    let chatSettings: VKIMChatSettingsItem?
    let important: Bool?
    let answered: Bool?

    enum CodingKeys: String, CodingKey {
        case peer
        case lastMessageId
        case inRead
        case outRead
        case unreadCount
        case canWrite
        case chatSettings
        case important
        case answered
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        peer = try? container.decode(VKPeer.self, forKey: .peer)
        lastMessageId = container.decodeSafeInt(forKey: .lastMessageId)
        inRead = container.decodeSafeInt(forKey: .inRead)
        outRead = container.decodeSafeInt(forKey: .outRead)
        unreadCount = container.decodeSafeInt(forKey: .unreadCount)
        canWrite = try? container.decode(VKCanWrite.self, forKey: .canWrite)
        chatSettings = try? container.decode(VKIMChatSettingsItem.self, forKey: .chatSettings)
        important = container.decodeSafeBool(forKey: .important)
        answered = container.decodeSafeBool(forKey: .answered)
    }
}

struct VKIMChatSettingsItem: Decodable {
    let id: Int?
    let title: String?
    let membersCount: Int?
    let adminId: Int?
    let photo: VKIMChatPhotoItem?
    let acl: ChatACL?
    let pinnedMessage: VKIMMessageItem?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case membersCount
        case adminId
        case photo
        case acl
        case pinnedMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeSafeInt(forKey: .id)
        title = container.decodeSafeString(forKey: .title)
        membersCount = container.decodeSafeInt(forKey: .membersCount)
        adminId = container.decodeSafeInt(forKey: .adminId)
        photo = try? container.decode(VKIMChatPhotoItem.self, forKey: .photo)
        acl = try? container.decode(ChatACL.self, forKey: .acl)
        pinnedMessage = try? container.decode(VKIMMessageItem.self, forKey: .pinnedMessage)
    }
}

struct VKIMChatPhotoItem: Decodable {
    let photo50: String?
    let photo100: String?
    let photo200: String?

    enum CodingKeys: String, CodingKey {
        case photo50
        case photo100
        case photo200
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        photo50 = container.decodeSafeString(forKey: .photo50)
        photo100 = container.decodeSafeString(forKey: .photo100)
        photo200 = container.decodeSafeString(forKey: .photo200)
    }
}

struct VKIMChatInfoItem: Decodable {
    let id: Int?
    let type: String?
    let title: String?
    let adminId: Int?
    let membersCount: Int?
    let photo50: String?
    let photo100: String?
    let photo200: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case adminId
        case membersCount
        case photo50
        case photo100
        case photo200
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeSafeInt(forKey: .id)
        type = container.decodeSafeString(forKey: .type)
        title = container.decodeSafeString(forKey: .title)
        adminId = container.decodeSafeInt(forKey: .adminId)
        membersCount = container.decodeSafeInt(forKey: .membersCount)
        photo50 = container.decodeSafeString(forKey: .photo50)
        photo100 = container.decodeSafeString(forKey: .photo100)
        photo200 = container.decodeSafeString(forKey: .photo200)
    }
}

struct VKPeer: Decodable {
    let id: Int?
    let type: String?
    let localId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case localId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeSafeInt(forKey: .id)
        type = container.decodeSafeString(forKey: .type)
        localId = container.decodeSafeInt(forKey: .localId)
    }
}

struct VKCanWrite: Decodable {
    let allowed: Bool?
    let reason: Int?

    enum CodingKeys: String, CodingKey {
        case allowed
        case reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allowed = container.decodeSafeBool(forKey: .allowed)
        reason = container.decodeSafeInt(forKey: .reason)
    }
}

struct VKIMMessageItem: Decodable {
    let id: Int?
    let peerId: Int?
    let userId: Int?
    let fromId: Int?
    let date: Int?
    let out: Int?
    let body: String?
    let text: String?
    let emoji: Bool?
    let isPinned: Bool?
    let isImportant: Bool?
    let isDeleted: Bool?
    let isEdited: Bool?
    let replyMessage: VKIMMessageReplyItem?
    let fwdMessages: [VKIMMessageReplyItem]?
    let attachments: [VKIMAttachmentItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case peerId
        case userId
        case fromId
        case date
        case out
        case body
        case text
        case message
        case emoji
        case isPinned
        case important
        case deleted
        case edited
        case replyMessage
        case fwdMessages = "fwd_messages"
        case attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeSafeInt(forKey: .id)
        peerId = container.decodeSafeInt(forKey: .peerId)
        userId = container.decodeSafeInt(forKey: .userId)
        fromId = container.decodeSafeInt(forKey: .fromId)
        date = container.decodeSafeInt(forKey: .date)
        out = container.decodeSafeInt(forKey: .out)
        body = container.decodeSafeString(forKey: .body)
        let rawText = container.decodeSafeString(forKey: .text) ?? container.decodeSafeString(forKey: .message) ?? container.decodeSafeString(forKey: .body)
        text = rawText
        emoji = container.decodeSafeBool(forKey: .emoji)
        isPinned = container.decodeSafeBool(forKey: .isPinned)
        isImportant = container.decodeSafeBool(forKey: .important)
        isDeleted = container.decodeSafeBool(forKey: .deleted)
        isEdited = container.decodeSafeBool(forKey: .edited)
        replyMessage = try? container.decode(VKIMMessageReplyItem.self, forKey: .replyMessage)
        fwdMessages = try? container.decode([VKIMMessageReplyItem].self, forKey: .fwdMessages)

        if let attArray = try? container.decode([VKIMAttachmentItem].self, forKey: .attachments) {
            attachments = attArray
        } else {
            attachments = []
        }
    }
}

struct VKIMMessageReplyItem: Decodable {
    let id: Int?
    let fromId: Int?
    let date: Int?
    let text: String?
    let attachments: [VKIMAttachmentItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case fromId
        case date
        case text
        case message
        case body
        case attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeSafeInt(forKey: .id)
        fromId = container.decodeSafeInt(forKey: .fromId)
        date = container.decodeSafeInt(forKey: .date)
        text = container.decodeSafeString(forKey: .text) ?? container.decodeSafeString(forKey: .message) ?? container.decodeSafeString(forKey: .body)

        if let attArray = try? container.decode([VKIMAttachmentItem].self, forKey: .attachments) {
            attachments = attArray
        } else {
            attachments = []
        }
    }
}

struct VKIMAttachmentItem: Decodable {
    let type: String?
    let photo: VKIMPhotoItem?
    let video: VKIMVideoItem?
    let audio: VKIMAudioItem?
    let doc: VKIMDocItem?
    let wall: VKIMWallItem?
    let sticker: VKIMStickerItem?
    let gift: VKIMGiftItem?

    enum CodingKeys: String, CodingKey {
        case type
        case photo
        case video
        case audio
        case doc
        case wall
        case sticker
        case gift
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decodeSafeString(forKey: .type)
        photo = try? container.decode(VKIMPhotoItem.self, forKey: .photo)
        video = try? container.decode(VKIMVideoItem.self, forKey: .video)
        audio = try? container.decode(VKIMAudioItem.self, forKey: .audio)
        doc = try? container.decode(VKIMDocItem.self, forKey: .doc)
        wall = try? container.decode(VKIMWallItem.self, forKey: .wall)
        sticker = try? container.decode(VKIMStickerItem.self, forKey: .sticker)
        gift = try? container.decode(VKIMGiftItem.self, forKey: .gift)
    }
}

struct VKIMPhotoItem: Decodable {
    let id: Int?
    let ownerId: Int?
    let text: String?
    let date: Int?
    let photo604: String?
    let photo807: String?
    let photo1280: String?
    let photo130: String?
    let sizes: [VKIMPhotoSizeItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case text
        case date
        case photo604
        case photo807
        case photo1280
        case photo130
        case sizes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(Int.self, forKey: .id)
        ownerId = try? container.decode(Int.self, forKey: .ownerId)
        text = try? container.decode(String.self, forKey: .text)
        date = try? container.decode(Int.self, forKey: .date)
        photo604 = try? container.decode(String.self, forKey: .photo604)
        photo807 = try? container.decode(String.self, forKey: .photo807)
        photo1280 = try? container.decode(String.self, forKey: .photo1280)
        photo130 = try? container.decode(String.self, forKey: .photo130)

        if let sizesArray = try? container.decode([VKIMPhotoSizeItem].self, forKey: .sizes) {
            sizes = sizesArray
        } else if let dict = try? container.decode([String: VKIMPhotoSizeItem].self, forKey: .sizes) {
            sizes = Array(dict.values)
        } else {
            sizes = nil
        }
    }
}

struct VKIMPhotoSizeItem: Decodable {
    let type: String?
    let url: String?
    let src: String?
    let width: Int?
    let height: Int?
}

struct VKIMVideoItem: Decodable {
    let id: Int?
    let ownerId: Int?
    let title: String?
    let duration: Int?
    let photo320: String?
    let photo800: String?
    let player: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case title
        case duration
        case photo320
        case photo800
        case player
    }
}

struct VKIMAudioItem: Decodable {
    let id: Int?
    let ownerId: Int?
    let artist: String?
    let title: String?
    let duration: Int?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case artist
        case title
        case duration
        case url
    }
}

struct VKIMDocItem: Decodable {
    let id: Int?
    let ownerId: Int?
    let title: String?
    let size: Int?
    let ext: String?
    let url: String?
    let preview: VKIMDocPreviewItem?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case title
        case size
        case ext
        case url
        case preview
    }
}

struct VKIMDocPreviewItem: Decodable {
    let photo: VKIMDocPreviewPhotoItem?

    enum CodingKeys: String, CodingKey {
        case photo
    }
}

struct VKIMDocPreviewPhotoItem: Decodable {
    let sizes: [VKIMPhotoSizeItem]?

    enum CodingKeys: String, CodingKey {
        case sizes
    }
}

struct VKIMWallItem: Decodable {
    let id: Int?
    let toId: Int?
    let fromId: Int?
    let date: Int?
    let text: String?
    let attachments: [VKIMAttachmentItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case toId
        case fromId
        case date
        case text
        case attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(Int.self, forKey: .id)
        toId = try? container.decode(Int.self, forKey: .toId)
        fromId = try? container.decode(Int.self, forKey: .fromId)
        date = try? container.decode(Int.self, forKey: .date)
        text = try? container.decode(String.self, forKey: .text)

        if let attArray = try? container.decode([VKIMAttachmentItem].self, forKey: .attachments) {
            attachments = attArray
        } else {
            attachments = []
        }
    }
}

struct VKIMStickerItem: Decodable {
    let stickerId: Int?
    let productId: Int?
    let images: [VKIMStickerImageItem]?

    enum CodingKeys: String, CodingKey {
        case stickerId
        case productId
        case images
    }
}

struct VKIMStickerImageItem: Decodable {
    let url: String?
    let width: Int?
    let height: Int?
}

struct VKIMGiftItem: Decodable {
    let id: Int?
    let thumb256: String?

    enum CodingKeys: String, CodingKey {
        case id
        case thumb256
    }
}

struct VKMessageHistoryResponse: Decodable {
    let count: Int?
    let items: [VKIMMessageItem]?
    let profiles: [VKUserProfile]?
    let groups: [VKGroupProfile]?
    let conversations: [VKIMConversationInfo]?

    enum CodingKeys: String, CodingKey {
        case count
        case items
        case profiles
        case groups
        case conversations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = container.decodeSafeInt(forKey: .count)
        items = try? container.decode([VKIMMessageItem].self, forKey: .items)
        profiles = try? container.decode([VKUserProfile].self, forKey: .profiles)
        groups = try? container.decode([VKGroupProfile].self, forKey: .groups)
        conversations = try? container.decode([VKIMConversationInfo].self, forKey: .conversations)
    }
}

struct VKSendMessageResponse: Decodable {
    let response: Int?
}

struct VKLongPollServerResponse: Decodable {
    let key: String?
    let server: String?
    let ts: Int?
    let pts: Int?
    let unreadCount: Int?

    enum CodingKeys: String, CodingKey {
        case key
        case server
        case ts
        case pts
        case unreadCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.decodeSafeString(forKey: .key)
        server = container.decodeSafeString(forKey: .server)
        ts = container.decodeSafeInt(forKey: .ts)
        pts = container.decodeSafeInt(forKey: .pts)
        unreadCount = container.decodeSafeInt(forKey: .unreadCount)
    }
}

struct VKConversationMembersResponse: Decodable {
    let count: Int?
    let items: [VKConversationMemberItem]?
    let profiles: [VKUserProfile]?
    let groups: [VKGroupProfile]?

    enum CodingKeys: String, CodingKey {
        case count
        case items
        case profiles
        case groups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = container.decodeSafeInt(forKey: .count)
        items = try? container.decode([VKConversationMemberItem].self, forKey: .items)
        profiles = try? container.decode([VKUserProfile].self, forKey: .profiles)
        groups = try? container.decode([VKGroupProfile].self, forKey: .groups)
    }
}

struct VKConversationMemberItem: Decodable {
    let memberId: Int?
    let invitedBy: Int?
    let joinDate: Int?
    let isAdmin: Bool?
    let canKick: Bool?

    enum CodingKeys: String, CodingKey {
        case memberId
        case invitedBy
        case joinDate
        case isAdmin
        case canKick
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = container.decodeSafeInt(forKey: .memberId)
        invitedBy = container.decodeSafeInt(forKey: .invitedBy)
        joinDate = container.decodeSafeInt(forKey: .joinDate)
        isAdmin = container.decodeSafeBool(forKey: .isAdmin)
        canKick = container.decodeSafeBool(forKey: .canKick)
    }
}

struct VKStickerPackDTO: Decodable {
    let id: Int?
    let title: String?
    let author: String?
    let description: String?
    let icon: String?
    let purchased: Int?
    let free: Int?
    let price: Int?
    let stickers: [VKIMStickerItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case description
        case icon
        case purchased
        case free
        case price
        case stickers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeSafeInt(forKey: .id)
        title = container.decodeSafeString(forKey: .title)
        author = container.decodeSafeString(forKey: .author)
        description = container.decodeSafeString(forKey: .description)
        icon = container.decodeSafeString(forKey: .icon)
        purchased = container.decodeSafeInt(forKey: .purchased)
        free = container.decodeSafeInt(forKey: .free)
        price = container.decodeSafeInt(forKey: .price)
        stickers = try? container.decode([VKIMStickerItem].self, forKey: .stickers)
    }
}

struct VKStickersResponse: Decodable {
    let count: Int?
    let items: [VKStickerPackDTO]?

    enum CodingKeys: String, CodingKey {
        case count
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = container.decodeSafeInt(forKey: .count)
        items = try? container.decode([VKStickerPackDTO].self, forKey: .items)
    }
}
