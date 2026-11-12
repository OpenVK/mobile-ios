//
//  Conversation.swift
//  OpenVK for iOS
//

import Foundation

struct Conversation: Identifiable, Hashable, Codable {
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
    var chatMemberCount: Int? = nil

    // Modern OpenVK IM conversation state.
    var inReadMessageID: Int = 0
    var outReadMessageID: Int = 0
    var inReadConversationMessageID: Int = 0
    var outReadConversationMessageID: Int = 0
    var lastConversationMessageID: Int = 0
    var isImportant: Bool = false
    var isUnanswered: Bool = false

    var isGroup: Bool { peer.isGroup == true }
}

struct ConversationsPage: Codable {
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
    let lastConversationMessageId: Int?
    let unreadCount: Int?
    let inRead: Int?
    let outRead: Int?
    let inReadCmid: Int?
    let outReadCmid: Int?
    let important: Bool?
    let unanswered: Bool?
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
    let membersCount: Int?
    let pinnedMessage: VKHistoryMessage?
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
    let fwdMessages: [VKHistoryMessage]?
    let readState: Int?
}

struct VKConversationAttachment: Decodable {
    let type: String?
    let sticker: VKSticker?
    let photo: VKMessagePhoto?
    let video: VKVideoAttachment?
    let doc: VKDocAttachment?
    let audio: VKAudioAttachment?
    let wall: VKMessageWallAttachment?
    let poll: VKPollAttachment?
    let link: VKMessageLinkAttachment?
    let gift: VKMessageGiftAttachment?
}

// Gift attachments may expose thumbnails at the top level or within "gift".
struct VKMessageGiftAsset: Decodable {
    let thumb48: String?
    let thumb96: String?
    let thumb256: String?

    private enum CodingKeys: String, CodingKey {
        case thumb48 = "thumb_48"
        case thumb96 = "thumb_96"
        case thumb256 = "thumb_256"
    }
}

struct VKMessageGiftAttachment: Decodable {
    let gift: VKMessageGiftAsset?
    let message: String?
    let thumb48: String?
    let thumb96: String?
    let thumb256: String?

    private enum CodingKeys: String, CodingKey {
        case gift, message
        case thumb48 = "thumb_48"
        case thumb96 = "thumb_96"
        case thumb256 = "thumb_256"
    }
}

struct ChatGift: Hashable, Codable {
    let previewURL: URL?
    let caption: String?

    init(_ gift: VKMessageGiftAttachment?) {
        let nested = gift?.gift
        let thumbnailCandidates: [String?] = [
            nested?.thumb256,
            gift?.thumb256,
            nested?.thumb96,
            gift?.thumb96,
            nested?.thumb48,
            gift?.thumb48
        ]
        let thumbnailURL: String? = thumbnailCandidates.compactMap { $0 }.first
        previewURL = thumbnailURL.flatMap { URL(string: $0) }
        caption = gift?.message?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct VKMessageLinkAttachment: Decodable {
    let title: String?
    let url: String?
}

struct VKWallViewCount: Decodable {
    let count: Int?
}

struct VKMessageWallAttachment: Decodable {
    let id: Int?
    let ownerId: Int?
    let fromId: Int?
    let date: Int?
    let text: String?
    let authorName: String?
    let authorAvatar: String?
    let views: VKWallViewCount?
    let attachments: [VKConversationAttachment]?
}

struct ChatAudio: Hashable, Codable {
    let vkID: Int?
    let ownerID: Int?
    let artist: String
    let title: String
    let duration: Int
    let url: URL?

    init(_ audio: VKAudioAttachment) {
        vkID = audio.id ?? audio.aid
        ownerID = audio.ownerID
        artist = audio.artist ?? ""
        title = audio.title?.isEmpty == false ? audio.title! : "Аудиозапись"
        duration = audio.duration ?? 0
        url = audio.url.flatMap(URL.init(string:))
    }

    var durationText: String {
        String(format: "%d:%02d", duration / 60, duration % 60)
    }

    var track: AudioTrack {
        AudioTrack(
            vkID: vkID,
            ownerID: ownerID,
            title: title,
            artist: artist.isEmpty ? "Неизвестный исполнитель" : artist,
            duration: durationText,
            durationSeconds: duration,
            url: url?.absoluteString
        )
    }
}

struct ChatPoll: Hashable, Codable {
    let question: String
    let answers: [String]
    let votes: Int

    init(_ poll: VKPollAttachment) {
        question = poll.question ?? "Опрос"
        answers = (poll.answers ?? []).compactMap(\.text)
        votes = poll.votes ?? 0
    }
}

struct ChatLink: Hashable, Codable {
    let title: String
    let url: URL?

    init(_ link: VKMessageLinkAttachment) {
        url = link.url.flatMap(URL.init)
        title = link.title?.isEmpty == false ? link.title! : (link.url ?? "Ссылка")
    }
}

struct ChatWallPost: Hashable, Codable {
    let authorName: String
    let authorAvatarURL: URL?
    let publicationDate: Date?
    let viewCount: Int?
    let text: String
    let url: URL?
    let attachments: [ChatWallAttachment]

    var postReference: (ownerID: Int, postID: Int)? {
        guard let path = url?.lastPathComponent, path.hasPrefix("wall") else { return nil }
        let parts = path.dropFirst(4).split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let ownerID = Int(parts[0]), let postID = Int(parts[1]) else { return nil }
        return (ownerID, postID)
    }

    init(_ wall: VKMessageWallAttachment, depth: Int) {
        let ownerID = wall.fromId ?? wall.ownerId ?? 0
        authorName = wall.authorName?.isEmpty == false
            ? wall.authorName!
            : (ownerID < 0 ? "Сообщество" : "Пользователь")
        authorAvatarURL = wall.authorAvatar.flatMap(URL.init)
        publicationDate = wall.date.flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil }
        viewCount = wall.views?.count
        text = wall.text ?? ""
        if let ownerID = wall.ownerId ?? wall.fromId, let id = wall.id {
            url = URL(string: "\(AppConfig.webBaseURL.absoluteString)wall\(ownerID)_\(id)")
        } else {
            url = nil
        }
        attachments = (wall.attachments ?? []).compactMap(ChatWallAttachment.init)
    }
}

enum ChatWallAttachment: Hashable, Codable {
    case photo(ChatPhoto)
    case video(ChatVideo)
    case audio(ChatAudio)
    case document(ChatDocument)
    case poll(ChatPoll)
    case link(ChatLink)
    case sticker(URL)
    case unsupported(String)

    init?(_ attachment: VKConversationAttachment) {
        switch attachment.type?.lowercased() {
        case "photo":
            guard let photo = attachment.photo?.chatPhoto else { return nil }
            self = .photo(photo)
        case "video":
            guard let video = attachment.video else { return nil }
            self = .video(ChatVideo(video: video))
        case "audio":
            guard let audio = attachment.audio else { return nil }
            self = .audio(ChatAudio(audio))
        case "doc", "document":
            guard let document = attachment.doc.flatMap(ChatDocument.init) else { return nil }
            self = .document(document)
        case "poll":
            guard let poll = attachment.poll else { return nil }
            self = .poll(ChatPoll(poll))
        case "link":
            guard let link = attachment.link else { return nil }
            self = .link(ChatLink(link))
        case "sticker":
            guard let url = attachment.sticker?.imageURL else { return nil }
            self = .sticker(url)
        default:
            guard let type = attachment.type else { return nil }
            self = .unsupported(type)
        }
    }

    var photos: [ChatPhoto] {
        if case .photo(let photo) = self { return [photo] }
        return []
    }

    var richAttachment: ChatRichAttachment {
        switch self {
        case .photo(let value): return .photo(value)
        case .video(let value): return .video(value)
        case .audio(let value): return .audio(value)
        case .document(let value): return .document(value)
        case .poll(let value): return .poll(value)
        case .link(let value): return .link(value)
        case .sticker(let value): return .sticker(value)
        case .unsupported(let value): return .unsupported(value)
        }
    }
}

enum ChatRichAttachment: Hashable, Codable {
    case photo(ChatPhoto)
    case video(ChatVideo)
    case audio(ChatAudio)
    case document(ChatDocument)
    case wall(ChatWallPost)
    case poll(ChatPoll)
    case link(ChatLink)
    case sticker(URL)
    case gift(ChatGift)
    case unsupported(String)

    var photos: [ChatPhoto] {
        switch self {
        case .photo(let photo): return [photo]
        case .wall(let wall): return wall.attachments.flatMap(\.photos)
        default: return []
        }
    }

    init?(_ attachment: VKConversationAttachment, depth: Int = 0) {
        switch attachment.type?.lowercased() {
        case "photo":
            guard let photo = attachment.photo?.chatPhoto else { return nil }
            self = .photo(photo)
        case "video":
            guard let video = attachment.video else { return nil }
            self = .video(ChatVideo(video: video))
        case "audio":
            guard let audio = attachment.audio else { return nil }
            self = .audio(ChatAudio(audio))
        case "doc", "document":
            guard let document = attachment.doc.flatMap(ChatDocument.init) else { return nil }
            self = .document(document)
        case "wall":
            guard let wall = attachment.wall, depth < 2 else { return nil }
            self = .wall(ChatWallPost(wall, depth: depth))
        case "gift":
            self = .gift(ChatGift(attachment.gift))
        case "poll":
            guard let poll = attachment.poll else { return nil }
            self = .poll(ChatPoll(poll))
        case "link":
            guard let link = attachment.link else { return nil }
            self = .link(ChatLink(link))
        case "sticker":
            guard let url = attachment.sticker?.imageURL else { return nil }
            self = .sticker(url)
        default:
            guard let type = attachment.type else { return nil }
            self = .unsupported(type)
        }
    }
}

struct VKMessagePhoto: Decodable {
    let id: Int?
    let ownerId: Int?
    let sizes: [VKPhotoSize]?

    var chatPhoto: ChatPhoto? {
        let preferredTypes = ["w", "z", "y", "x", "r", "q"]
        let preferredSize = preferredTypes.compactMap { preferredType in
            sizes?.first(where: { $0.type == preferredType })
        }.first ?? sizes?.last
        let urlString = preferredSize?.url ?? preferredSize?.src
        guard let urlString, let url = URL(string: urlString) else { return nil }
        return ChatPhoto(
            id: id,
            ownerID: ownerId,
            url: url,
            width: preferredSize?.width,
            height: preferredSize?.height
        )
    }
}

struct ChatPhoto: Identifiable, Hashable, Codable {
    let id: String
    let url: URL
    let aspectRatio: Double

    init(id: Int?, ownerID: Int?, url: URL, width: Int? = nil, height: Int? = nil) {
        self.id = "\(ownerID ?? 0)_\(id ?? 0)_\(url.absoluteString)"
        self.url = url
        self.aspectRatio = {
            guard let width, let height, height > 0 else { return 1 }
            return Double(width) / Double(height)
        }()
    }
}

struct ChatVideo: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let duration: Int
    let thumbnailURL: URL?
    let playerURL: URL?
    let files: [String: String]?

    init(video: VKVideoAttachment) {
        let videoID = video.id ?? 0
        let ownerID = video.ownerId ?? 0
        id = "\(ownerID)_\(videoID)"
        title = video.title ?? "Видео"
        duration = video.duration ?? 0
        thumbnailURL = (video.image?.last?.url ?? video.image?.first?.url).flatMap(URL.init)
        playerURL = video.player.flatMap(URL.init)
        files = video.files
    }

    var preferredURL: URL? {
        let preferredQualities = ["mp4_720", "mp4_480", "mp4_360", "mp4_240"]
        return preferredQualities.compactMap { files?[$0].flatMap(URL.init) }.first ?? playerURL
    }

    var preferredQuality: String {
        let preferredQualities = ["mp4_720", "mp4_480", "mp4_360", "mp4_240"]
        return preferredQualities.first(where: { files?[$0] != nil }) ?? files?.keys.sorted().first ?? ""
    }

    var durationText: String {
        let minutes = duration / 60
        return String(format: "%d:%02d", minutes, duration % 60)
    }
}

struct ChatDocument: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let ext: String
    let size: Int
    let url: String
    let isGIF: Bool
    let aspectRatio: Double

    init?(attachment: VKDocAttachment) {
        guard let url = attachment.url, !url.isEmpty else { return nil }
        self.url = url
        title = attachment.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? attachment.title!
            : "Документ"
        ext = attachment.ext?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        size = attachment.size ?? 0
        isGIF = attachment.isGif == 1 || ext.lowercased() == "gif"
        let previewSize = attachment.preview?.photo?.sizes?.last(where: {
            ($0.width ?? 0) > 0 && ($0.height ?? 0) > 0
        })
        if let width = previewSize?.width, let height = previewSize?.height, height > 0 {
            aspectRatio = Double(width) / Double(height)
        } else {
            aspectRatio = 1
        }
        id = "\(url)|\(title)"
    }

    var formattedSize: String {
        guard size > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct VKSticker: Codable {
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

struct VKStickerImage: Codable {
    let url: String?
    let width: Int
}

struct VKStickerAnimation: Codable {
    let url: String?
}

struct VKStickerPack: Codable, Identifiable {
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
    let conversationMessageId: Int?
    let randomId: Int?
    let fromId: Int?
    let peerId: Int?
    let date: Int?
    let out: Int?
    let body: String?
    let text: String?
    let attachments: [VKConversationAttachment]?
    let deleted: Int?
    let readState: Int?
    let readBy: [Int]?
    let important: Bool?
    let isPinned: Int?
    let action: VKMessageAction?
    let actionMid: Int?
    let edited: Bool?
    let editedAt: Int?
    let replyMessage: VKReplyMessage?
    let fwdMessages: [VKHistoryMessage]?
}

struct VKReplyMessage: Decodable {
    let id: Int?
    let fromId: Int?
    let body: String?
    let text: String?
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

struct ChatReply: Hashable, Codable {
    let messageID: Int
    let senderName: String
    let text: String
}

struct ChatForwardedMessage: Hashable, Codable {
    let senderName: String
    let text: String
    let attachments: [ChatRichAttachment]
    let forwardedMessages: [ChatForwardedMessage]

    var photos: [ChatPhoto] {
        attachments.flatMap(\.photos) + forwardedMessages.flatMap(\.photos)
    }

    init(_ message: VKHistoryMessage, profiles: [VKUserProfile], depth: Int = 0) {
        let senderID = message.fromId ?? 0
        let profile = profiles.first(where: { $0.id == abs(senderID) })
        let name = [profile?.firstName, profile?.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        senderName = name.isEmpty ? "Пользователь" : name
        text = message.body ?? message.text ?? ""
        attachments = (message.attachments ?? []).compactMap { ChatRichAttachment($0) }
        forwardedMessages = depth < 2
            ? (message.fwdMessages ?? []).map { ChatForwardedMessage($0, profiles: profiles, depth: depth + 1) }
            : []
    }
}

struct ChatMessage: Identifiable, Hashable, Codable {
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
    let videos: [ChatVideo]
    let documents: [ChatDocument]
    let gifs: [ChatDocument]
    let richAttachments: [ChatRichAttachment]?
    let forwardedMessages: [ChatForwardedMessage]?
    let reply: ChatReply?
    let systemEventText: String?
    let isDeleted: Bool
    let isEdited: Bool
    let deliveryStatus: MessageDeliveryStatus?
    var incomingReadState: Int? = nil
    let endsChatParticipation: Bool

    // Modern OpenVK IM metadata. These are mutable so local actions can update
    // the UI immediately while Long Poll/API history later reconciles state.
    var conversationMessageID: Int? = nil
    var randomID: Int? = nil
    var peerID: Int? = nil
    var readBy: [Int] = []
    var isImportant: Bool = false
    var isPinned: Bool = false

    var allPhotos: [ChatPhoto] {
        (richAttachments?.flatMap(\.photos) ?? photos)
            + (forwardedMessages ?? []).flatMap(\.photos)
    }

    init(message: VKHistoryMessage, profiles: [VKUserProfile]) {
        let senderID = message.fromId ?? 0
        id = message.id ?? Int.random(in: 1...Int.max)
        let body = message.body ?? message.text ?? ""
        let attachments = message.attachments ?? []
        let photos = attachments.compactMap { $0.photo?.chatPhoto }
        let videos = attachments.compactMap { $0.video.map(ChatVideo.init) }
        let documents = attachments.compactMap { $0.doc.flatMap(ChatDocument.init) }
        let gifs = documents.filter(\.isGIF)
        let regularDocuments = documents.filter { !$0.isGIF }
        let richAttachments = attachments.compactMap { ChatRichAttachment($0) }
        let forwardedMessages = (message.fwdMessages ?? []).map { ChatForwardedMessage($0, profiles: profiles) }
        text = body.isEmpty && (!richAttachments.isEmpty || !forwardedMessages.isEmpty)
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
        self.videos = videos
        self.documents = regularDocuments
        self.gifs = gifs
        self.richAttachments = richAttachments
        self.forwardedMessages = forwardedMessages
        reply = message.replyMessage.map { replyMessage in
            let replySenderID = replyMessage.fromId ?? 0
            let profile = profiles.first(where: { $0.id == abs(replySenderID) })
            let name = [profile?.firstName, profile?.lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return ChatReply(
                messageID: replyMessage.id ?? 0,
                senderName: name.isEmpty ? "Пользователь" : name,
                text: replyMessage.body ?? replyMessage.text ?? "Вложение"
            )
        }
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
        isEdited = message.edited == true || message.editedAt != nil
        deliveryStatus = isOutgoing ? ((message.readState ?? 0) == 1 ? .read : .unread) : nil
        incomingReadState = isOutgoing ? nil : message.readState
        conversationMessageID = message.conversationMessageId
        randomID = message.randomId
        peerID = message.peerId
        readBy = message.readBy ?? []
        isImportant = message.important == true
        isPinned = message.isPinned == 1
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
        videos: [ChatVideo],
        documents: [ChatDocument],
        gifs: [ChatDocument],
        richAttachments: [ChatRichAttachment]? = nil,
        forwardedMessages: [ChatForwardedMessage]? = nil,
        reply: ChatReply? = nil,
        systemEventText: String?,
        isDeleted: Bool,
        isEdited: Bool = false,
        deliveryStatus: MessageDeliveryStatus?,
        incomingReadState: Int? = nil,
        endsChatParticipation: Bool = false,
        conversationMessageID: Int? = nil,
        randomID: Int? = nil,
        peerID: Int? = nil,
        readBy: [Int] = [],
        isImportant: Bool = false,
        isPinned: Bool = false
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
        self.videos = videos
        self.documents = documents
        self.gifs = gifs
        self.richAttachments = richAttachments
        self.forwardedMessages = forwardedMessages
        self.reply = reply
        self.systemEventText = systemEventText
        self.isDeleted = isDeleted
        self.isEdited = isEdited
        self.deliveryStatus = deliveryStatus
        self.incomingReadState = incomingReadState
        self.endsChatParticipation = endsChatParticipation
        self.conversationMessageID = conversationMessageID
        self.randomID = randomID
        self.peerID = peerID
        self.readBy = readBy
        self.isImportant = isImportant
        self.isPinned = isPinned
    }

    static func pending(text: String, replyTo: ChatMessage? = nil) -> ChatMessage {
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
            videos: [],
            documents: [],
            gifs: [],
            reply: replyTo.map {
                ChatReply(
                    messageID: $0.id,
                    senderName: $0.senderName ?? "Пользователь",
                    text: $0.text.isEmpty ? "Вложение" : $0.text
                )
            },
            systemEventText: nil,
            isDeleted: false,
            isEdited: false,
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
            videos: [],
            documents: [],
            gifs: [],
            reply: nil,
            systemEventText: nil,
            isDeleted: false,
            isEdited: false,
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
            videos: videos,
            documents: documents,
            gifs: gifs,
            richAttachments: richAttachments,
            forwardedMessages: forwardedMessages,
            reply: reply,
            systemEventText: systemEventText,
            isDeleted: isDeleted,
            isEdited: isEdited,
            deliveryStatus: status,
            incomingReadState: incomingReadState,
            endsChatParticipation: endsChatParticipation,
            conversationMessageID: conversationMessageID,
            randomID: randomID,
            peerID: peerID,
            readBy: readBy,
            isImportant: isImportant,
            isPinned: isPinned
        )
    }

    func updatingText(_ value: String) -> ChatMessage {
        ChatMessage(
            id: id, text: value, date: date, isOutgoing: isOutgoing, senderID: senderID,
            senderName: senderName, senderAvatarURL: senderAvatarURL, attachmentTypes: attachmentTypes,
            stickerURL: stickerURL, stickerAnimationURL: stickerAnimationURL, photos: photos, videos: videos,
            documents: documents, gifs: gifs, richAttachments: richAttachments,
            forwardedMessages: forwardedMessages, reply: reply,
            systemEventText: systemEventText, isDeleted: isDeleted, isEdited: true, deliveryStatus: deliveryStatus,
            incomingReadState: incomingReadState,
            endsChatParticipation: endsChatParticipation, conversationMessageID: conversationMessageID,
            randomID: randomID, peerID: peerID, readBy: readBy, isImportant: isImportant, isPinned: isPinned
        )
    }

    func markingDeleted() -> ChatMessage {
        ChatMessage(
            id: id, text: text, date: date, isOutgoing: isOutgoing, senderID: senderID,
            senderName: senderName, senderAvatarURL: senderAvatarURL, attachmentTypes: attachmentTypes,
            stickerURL: stickerURL, stickerAnimationURL: stickerAnimationURL, photos: photos, videos: videos,
            documents: documents, gifs: gifs, richAttachments: richAttachments,
            forwardedMessages: forwardedMessages, reply: reply,
            systemEventText: systemEventText, isDeleted: true, isEdited: isEdited, deliveryStatus: deliveryStatus,
            incomingReadState: incomingReadState,
            endsChatParticipation: endsChatParticipation, conversationMessageID: conversationMessageID,
            randomID: randomID, peerID: peerID, readBy: readBy, isImportant: isImportant, isPinned: isPinned
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
        case "coins_transfer":
            // member_id is the number of voices here, not another user's ID.
            let amount = memberID.flatMap { $0 > 0 ? $0 : nil }
            let quantity: String
            if let amount {
                let lastTwo = amount % 100
                let last = amount % 10
                let noun = (11...14).contains(lastTwo) ? "голосов"
                    : last == 1 ? "голос"
                    : (2...4).contains(last) ? "голоса" : "голосов"
                quantity = "\(amount) \(noun)"
            } else {
                quantity = "голоса"
            }
            let headline = actorID == AuthService.shared.currentUser?.uid
                ? "Вы отправили \(quantity)"
                : "\(actorName) отправил(а) вам \(quantity)"
            let note = action?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return note.isEmpty ? headline : "\(headline): «\(note)»"
        case "rating_up":
            let note = action?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return note.isEmpty ? "\(actorName) повысил(а) рейтинг"
                : "\(actorName) повысил(а) рейтинг: «\(note)»"
        default:
            let text = action?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            return text?.isEmpty == false ? text : "Системное сообщение"
        }
    }
}

enum MessageDeliveryStatus: Hashable, Codable {
    case sending
    case unread
    case read
    case failed
}
