//
//  ChatInfoService.swift
//  OpenVK for iOS
//

import Foundation

enum ChatMaterialSection: String, CaseIterable, Identifiable {
    case members
    case photos
    case videos
    case audio
    case documents
    case links

    var id: String { rawValue }

    var title: String {
        switch self {
        case .members: return "Участники"
        case .photos: return "Фотографии"
        case .videos: return "Видео"
        case .audio: return "Аудио"
        case .documents: return "Документы"
        case .links: return "Ссылки"
        }
    }

    var mediaType: String? {
        switch self {
        case .members: return nil
        case .photos: return "photo"
        case .videos: return "video"
        case .audio: return "audio"
        case .documents: return "doc"
        case .links: return "link"
        }
    }
}

struct ChatMember: Identifiable {
    let id: Int
    let user: User
    let isOwner: Bool
    let isModerator: Bool
    let canKick: Bool?

    var roleTitle: String? {
        if isOwner { return "Владелец" }
        if isModerator { return "Модератор" }
        return nil
    }
}

struct ChatMembersPage {
    let members: [ChatMember]
    let count: Int
    let title: String?
    let photoURL: URL?
    let canInvite: Bool
    let canPromote: Bool
    let canModerate: Bool
    let canSeeInviteLink: Bool
    let canChangeInfo: Bool
    let canChangePin: Bool
    let canChangeInviteLink: Bool
    let isOwner: Bool
    let isModerator: Bool
}

struct ChatMaterial: Identifiable {
    let id = UUID()
    let photoURL: URL?
    let videoURL: URL?
    let audioURL: URL?
    let documentURL: URL?
    let linkURL: URL?
    let title: String
    let subtitle: String?
}

struct ChatMaterialsPage {
    let items: [ChatMaterial]
    let nextFrom: String?
}

protocol ChatInfoServiceProtocol {
    func getMembers(peerID: Int) async throws -> ChatMembersPage
    func getMaterials(peerID: Int, section: ChatMaterialSection, startFrom: String?) async throws -> ChatMaterialsPage
    func addUsers(peerID: Int, userIDs: [Int]) async throws
    func setRole(peerID: Int, userID: Int, moderator: Bool) async throws
    func removeUser(peerID: Int, userID: Int) async throws
    func getMuted(peerID: Int) async throws -> Bool
    func setMuted(peerID: Int, muted: Bool) async throws
    func getInviteLink(peerID: Int) async throws -> URL
}

struct ChatInfoService: ChatInfoServiceProtocol {
    let client: APIClientProtocol

    init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    func getMembers(peerID: Int) async throws -> ChatMembersPage {
        let response = try await client.call(
            method: "messages.getConversationMembers",
            parameters: ["peer_id": String(peerID), "extended": "1"],
            httpMethod: "GET",
            as: ChatMembersResponse.self
        )
        let settings = response.chatSettings
        let myID = AuthService.shared.currentUser?.uid ?? 0
        let profiles = Dictionary((response.profiles ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let groups = Dictionary((response.groups ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let members = response.items.map { item -> ChatMember in
            let id = item.memberId ?? item.id ?? 0
            let owner = item.isOwner?.value == true || id == settings?.ownerId
                || (settings?.ownerId == nil && id == settings?.adminId && item.isModerator?.value != true)
            let moderator = !owner && (item.isModerator?.value == true || item.isAdmin?.value == true
                || settings?.adminIds?.contains(id) == true)
            let user: User
            if id < 0, let group = groups[abs(id)] {
                user = User(
                    uid: id,
                    username: group.screenName ?? "club\(abs(id))",
                    displayName: group.name ?? "Сообщество",
                    avatarURL: (group.photo200 ?? group.photo100).flatMap(URL.init),
                    isGroup: true
                )
            } else if let profile = profiles[id] {
                let name = [profile.firstName, profile.lastName]
                    .compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                user = User(
                    uid: id,
                    username: profile.screenName ?? "id\(id)",
                    displayName: name.isEmpty ? "Пользователь \(id)" : name,
                    avatarURL: (profile.photo200 ?? profile.photo100).flatMap(URL.init),
                    isOnline: profile.online == 1,
                    isOfficial: profile.verified == 1
                )
            } else {
                user = User(uid: id, username: id < 0 ? "club\(abs(id))" : "id\(id)", displayName: id < 0 ? "Сообщество" : "Пользователь \(id)")
            }
            return ChatMember(id: id, user: user, isOwner: owner, isModerator: moderator, canKick: item.canKick?.value)
        }.filter { $0.id != 0 }
        let current = members.first { $0.id == myID }
        let isOwner = current?.isOwner == true || myID > 0 && myID == settings?.ownerId
        let isModerator = current?.isModerator == true
        let isMember = current != nil
        let acl = settings?.acl
        return ChatMembersPage(
            members: members,
            count: max(response.count ?? members.count, members.count),
            title: settings?.title,
            photoURL: (settings?.photo200 ?? settings?.photo100).flatMap(URL.init),
            canInvite: isMember && (acl?.canInvite?.value ?? true),
            canPromote: isMember && (acl?.canPromoteUsers?.value ?? isOwner),
            canModerate: isMember && (acl?.canModerate?.value ?? (isOwner || isModerator)),
            canSeeInviteLink: isMember && (acl?.canSeeInviteLink?.value ?? (isOwner || isModerator)),
            canChangeInfo: isMember && (acl?.canChangeInfo?.value ?? (isOwner || isModerator)),
            canChangePin: isMember && (acl?.canChangePin?.value ?? (isOwner || isModerator)),
            canChangeInviteLink: isMember && (acl?.canChangeInviteLink?.value ?? isOwner),
            isOwner: isOwner,
            isModerator: isModerator
        )
    }

    func getMaterials(peerID: Int, section: ChatMaterialSection, startFrom: String?) async throws -> ChatMaterialsPage {
        guard let mediaType = section.mediaType else { return ChatMaterialsPage(items: [], nextFrom: nil) }
        var parameters = ["peer_id": String(peerID), "media_type": mediaType, "count": "40", "photo_sizes": "1"]
        if let startFrom, !startFrom.isEmpty { parameters["start_from"] = startFrom }
        let response = try await client.call(
            method: "messages.getHistoryAttachments", parameters: parameters,
            httpMethod: "GET", as: ChatMaterialsResponse.self
        )
        var items: [ChatMaterial] = []
        for item in response.items ?? [] {
            guard let attachment = item.attachment else { continue }
            let material: ChatMaterial?
            switch section {
            case .members: material = nil
            case .photos:
                if let url = attachment.photo?.bestURL {
                    material = ChatMaterial(photoURL: url, videoURL: nil, audioURL: nil, documentURL: nil, linkURL: nil, title: "Фотография", subtitle: nil)
                } else { material = nil }
            case .videos:
                if let video = attachment.video {
                    let thumbnail = video.image?
                        .max { ($0.width ?? 0) * ($0.height ?? 0) < ($1.width ?? 0) * ($1.height ?? 0) }
                        .flatMap { URL(string: $0.url) }
                    let player = (video.files?["mp4_720"] ?? video.files?["mp4_480"] ?? video.player).flatMap { URL(string: $0) }
                    material = ChatMaterial(photoURL: thumbnail, videoURL: player, audioURL: nil, documentURL: nil, linkURL: nil, title: video.title ?? "Видео", subtitle: nil)
                } else { material = nil }
            case .audio:
                if let audio = attachment.audio {
                    material = ChatMaterial(photoURL: nil, videoURL: nil, audioURL: (audio.manifest ?? audio.url).flatMap { URL(string: $0) }, documentURL: nil, linkURL: nil, title: audio.title ?? "Аудиозапись", subtitle: audio.artist)
                } else { material = nil }
            case .documents:
                if let document = attachment.doc {
                    material = ChatMaterial(photoURL: nil, videoURL: nil, audioURL: nil, documentURL: document.url.flatMap { URL(string: $0) }, linkURL: nil, title: document.title ?? "Документ", subtitle: document.ext?.uppercased())
                } else { material = nil }
            case .links:
                if let link = attachment.link, let url = link.url.flatMap({ URL(string: $0) }) {
                    material = ChatMaterial(photoURL: nil, videoURL: nil, audioURL: nil, documentURL: nil, linkURL: url, title: link.title ?? link.url ?? "Ссылка", subtitle: url.host)
                } else { material = nil }
            }
            if let material { items.append(material) }
        }
        return ChatMaterialsPage(items: items, nextFrom: response.nextFrom?.isEmpty == false ? response.nextFrom : nil)
    }

    func addUsers(peerID: Int, userIDs: [Int]) async throws {
        guard !userIDs.isEmpty else { return }
        let _: Int = try await client.call(method: "messages.addChatUser", parameters: [
            "peer_id": String(peerID), "user_id": userIDs.map(String.init).joined(separator: ",")
        ], httpMethod: "POST", as: Int.self)
    }

    func setRole(peerID: Int, userID: Int, moderator: Bool) async throws {
        let _: Int = try await client.call(method: "messages.setMemberRole", parameters: [
            "peer_id": String(peerID), "user_id": String(userID), "role": moderator ? "admin" : "member"
        ], httpMethod: "POST", as: Int.self)
    }

    func removeUser(peerID: Int, userID: Int) async throws {
        let _: Int = try await client.call(method: "messages.removeChatUser", parameters: [
            "peer_id": String(peerID), "user_id": String(userID)
        ], httpMethod: "POST", as: Int.self)
    }

    func getMuted(peerID: Int) async throws -> Bool {
        let settings = try await client.call(method: "account.getPushSettings", parameters: ["peer_id": String(peerID)], httpMethod: "GET", as: ChatPushSettings.self)
        return settings.sound == 0 || (settings.disabledUntil ?? 0) == -1
            || (settings.disabledUntil ?? 0) > Int(Date().timeIntervalSince1970)
    }

    func setMuted(peerID: Int, muted: Bool) async throws {
        let _: Int = try await client.call(method: "account.setSilenceMode", parameters: [
            "peer_id": String(peerID), "time": muted ? "-1" : "0", "sound": muted ? "0" : "1"
        ], httpMethod: "POST", as: Int.self)
    }

    func getInviteLink(peerID: Int) async throws -> URL {
        let response = try await client.call(method: "messages.getInviteLink", parameters: ["peer_id": String(peerID)], httpMethod: "GET", as: ChatInviteLinkResponse.self)
        guard let url = URL(string: response.link) else { throw URLError(.badURL) }
        return url
    }

}

private struct APIFlag: Decodable {
    let value: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) { value = bool }
        else if let int = try? container.decode(Int.self) { value = int != 0 }
        else if let string = try? container.decode(String.self) { value = string == "1" || string.lowercased() == "true" }
        else { value = false }
    }
}

private struct ChatMembersResponse: Decodable {
    let count: Int?
    let items: [ChatMemberResponse]
    let profiles: [VKUserProfile]?
    let groups: [VKGroupProfile]?
    let chatSettings: ChatSettingsResponse?
}

private struct ChatMemberResponse: Decodable {
    let memberId: Int?
    let id: Int?
    let isOwner: APIFlag?
    let isModerator: APIFlag?
    let isAdmin: APIFlag?
    let canKick: APIFlag?
}

private struct ChatSettingsResponse: Decodable {
    let title: String?
    let photo100: String?
    let photo200: String?
    let ownerId: Int?
    let adminId: Int?
    let adminIds: [Int]?
    let acl: ChatACLResponse?
}

private struct ChatACLResponse: Decodable {
    let canInvite: APIFlag?
    let canPromoteUsers: APIFlag?
    let canModerate: APIFlag?
    let canSeeInviteLink: APIFlag?
    let canChangeInfo: APIFlag?
    let canChangePin: APIFlag?
    let canChangeInviteLink: APIFlag?
}

private struct ChatMaterialsResponse: Decodable {
    let items: [ChatMaterialItemResponse]?
    let nextFrom: String?
}

private struct ChatMaterialItemResponse: Decodable {
    let attachment: ChatMaterialAttachmentResponse?
}

private struct ChatMaterialAttachmentResponse: Decodable {
    let photo: ChatMaterialPhotoResponse?
    let video: VKVideoAttachment?
    let audio: ChatMaterialAudioResponse?
    let doc: VKDocAttachment?
    let link: ChatMaterialLinkResponse?
}

private struct ChatMaterialPhotoResponse: Decodable {
    let sizes: VKPhotoSizes?
    let photo604: String?
    let photo130: String?
    let url: String?

    var bestURL: URL? {
        let largest = sizes?.array
            .filter { $0.url != nil || $0.src != nil }
            .max { ($0.width ?? 0) * ($0.height ?? 0) < ($1.width ?? 0) * ($1.height ?? 0) }
        return (largest?.url ?? largest?.src ?? photo604 ?? photo130 ?? url).flatMap { URL(string: $0) }
    }
}

private struct ChatMaterialAudioResponse: Decodable {
    let title: String?
    let artist: String?
    let url: String?
    let manifest: String?
}

private struct ChatMaterialLinkResponse: Decodable {
    let title: String?
    let description: String?
    let url: String?
}

private struct ChatPushSettings: Decodable {
    let disabledUntil: Int?
    let sound: Int?
}

private struct ChatInviteLinkResponse: Decodable {
    let link: String
}
