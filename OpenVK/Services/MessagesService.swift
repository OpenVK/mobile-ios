//
//  MessagesService.swift
//  OpenVK for iOS
//

import Foundation

protocol MessagesServiceProtocol {
    func fetchConversations(offset: Int, count: Int, completion: @escaping (Result<ConversationsPage, Error>) -> Void)
    func fetchHistory(peerID: Int, offset: Int, count: Int, completion: @escaping (Result<MessagesPage, Error>) -> Void)
    func sendMessage(peerID: Int, text: String, completion: @escaping (Result<Int, Error>) -> Void)
    func sendSticker(peerID: Int, stickerID: Int, completion: @escaping (Result<Int, Error>) -> Void)
    func fetchStickerPacks(completion: @escaping (Result<[VKStickerPack], Error>) -> Void)
    func setTyping(peerID: Int)
    func markAsRead(peerID: Int)
    func markConversationAsRead(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteConversation(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func leaveChat(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void)
}

final class MessagesService: MessagesServiceProtocol {
    static let shared = MessagesService()

    private let client: APIClientProtocol

    private init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    func fetchHistory(peerID: Int, offset: Int = 0, count: Int = 40, completion: @escaping (Result<MessagesPage, Error>) -> Void) {
        client.call(
            method: "messages.getHistory",
            parameters: ["peer_id": String(peerID), "offset": String(offset), "count": String(count), "extended": "1"],
            httpMethod: "GET",
            as: VKMessagesHistoryResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let profiles = response.profiles ?? []
                let messages = (response.items ?? []).map { ChatMessage(message: $0, profiles: profiles) }.reversed()
                completion(.success(MessagesPage(count: response.count ?? messages.count, messages: Array(messages))))
            case .failure(let error): completion(.failure(error))
            }
        }
    }

    func sendMessage(peerID: Int, text: String, completion: @escaping (Result<Int, Error>) -> Void) {
        client.call(
            method: "messages.send",
            parameters: ["peer_id": String(peerID), "message": text, "random_id": String(Int.random(in: 1...Int.max))],
            httpMethod: "POST",
            as: Int.self,
            completion: { result in completion(result.mapError { $0 as Error }) }
        )
    }

    func sendSticker(peerID: Int, stickerID: Int, completion: @escaping (Result<Int, Error>) -> Void) {
        client.call(
            method: "messages.send",
            parameters: ["peer_id": String(peerID), "sticker_id": String(stickerID), "random_id": String(Int.random(in: 1...Int.max))],
            httpMethod: "POST",
            as: Int.self,
            completion: { result in completion(result.mapError { $0 as Error }) }
        )
    }

    func fetchStickerPacks(completion: @escaping (Result<[VKStickerPack], Error>) -> Void) {
        client.call(
            method: "stickers.get",
            parameters: ["count": "100"],
            httpMethod: "GET",
            as: VKStickerPacksResponse.self
        ) { result in
            completion(result.map { $0.items ?? [] }.mapError { $0 as Error })
        }
    }

    func setTyping(peerID: Int) {
        client.call(
            method: "messages.setActivity",
            parameters: ["peer_id": String(peerID), "type": "typing"],
            httpMethod: "POST",
            as: Int.self
        ) { _ in }
    }

    func markAsRead(peerID: Int) {
        client.call(method: "messages.markAsRead", parameters: ["peer_id": String(peerID)], httpMethod: "POST", as: Int.self) { _ in }
    }

    func markConversationAsRead(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.markAsRead",
            parameters: ["peer_id": String(peerID)],
            httpMethod: "POST",
            as: Int.self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func deleteConversation(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.deleteConversation",
            parameters: ["peer_id": String(peerID)],
            httpMethod: "POST",
            as: Int.self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func leaveChat(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.removeChatUser",
            parameters: ["peer_id": String(peerID)],
            httpMethod: "POST",
            as: Int.self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func fetchConversations(
        offset: Int = 0,
        count: Int = 30,
        completion: @escaping (Result<ConversationsPage, Error>) -> Void
    ) {
        let parameters: [String: String] = [
            "offset": String(offset),
            "count": String(count),
            "filter": "all",
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,photo_200,online,last_seen,verified"
        ]

        client.call(
            method: "messages.getConversations",
            parameters: parameters,
            httpMethod: "GET",
            as: VKConversationsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let profiles = response.profiles ?? []
                let groups = response.groups ?? []
                let conversations = (response.items ?? []).map {
                    self.makeConversation(from: $0, profiles: profiles, groups: groups)
                }
                completion(.success(ConversationsPage(
                    totalCount: response.count ?? conversations.count,
                    conversations: conversations
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func makeConversation(
        from item: VKConversationItem,
        profiles: [VKUserProfile],
        groups: [VKGroupProfile]
    ) -> Conversation {
        let peer = item.conversation.peer
        let peerUser: User
        let isChat = peer.type == "chat" || peer.id >= 2_000_000_000

        if isChat {
            let settings = item.conversation.chatSettings
            peerUser = User(
                uid: peer.id,
                username: "",
                displayName: settings?.title?.isEmpty == false ? settings!.title! : "Беседа",
                avatarURL: settings?.photo100.flatMap(URL.init)
            )
        } else if peer.id < 0, let group = groups.first(where: { $0.id == abs(peer.id) }) {
            peerUser = User(
                uid: peer.id,
                username: group.screenName ?? "club" + String(abs(peer.id)),
                displayName: group.name ?? "Сообщество",
                avatarURL: (group.photo200 ?? group.photo100).flatMap(URL.init),
                isGroup: true,
                isOfficial: group.verified == 1
            )
        } else if let profile = profiles.first(where: { $0.id == abs(peer.id) }) {
            let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                .trimmingCharacters(in: .whitespacesAndNewlines)
            peerUser = User(
                uid: peer.id,
                username: profile.screenName ?? "id" + String(abs(peer.id)),
                displayName: name.isEmpty ? "Пользователь" : name,
                avatarURL: (profile.photo200 ?? profile.photo100).flatMap(URL.init),
                isOnline: profile.online == 1,
                onlinePlatform: profile.lastSeen?.platformName,
                lastSeen: profile.lastSeen?.time.map { Date(timeIntervalSince1970: $0).openvkLastSeen(sex: profile.sex) },
                isOfficial: profile.verified == 1
            )
        } else {
            peerUser = User(
                uid: peer.id,
                username: "id" + String(abs(peer.id)),
                displayName: "Пользователь " + String(abs(peer.id))
            )
        }

        let message = item.lastMessage
        let timestamp = TimeInterval(message?.date ?? 0)
        let authorName: String?
        if message?.out == 1 {
            authorName = "Вы"
        } else if let fromId = message?.fromId {
            authorName = messageAuthorName(
                fromId: fromId,
                profiles: profiles,
                groups: groups
            ) ?? peerUser.displayName
        } else {
            authorName = message == nil ? nil : peerUser.displayName
        }

        let messageText = messagePreview(message)
        return Conversation(
            id: peer.id,
            peer: peerUser,
            lastMessage: messageText,
            lastMessageAuthorName: authorName,
            lastMessageOutgoing: message?.out == 1,
            updatedAt: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : Date(),
            unreadCount: item.conversation.unreadCount ?? 0,
            lastMessageId: item.conversation.lastMessageId ?? message?.id ?? 0,
            lastMessageReadState: message?.readState,
            isChat: isChat,
            isChatMember: !["left", "kicked"].contains(item.conversation.chatSettings?.state?.lowercased())
                && item.conversation.canWrite?.allowed != false
                && item.conversation.canWrite?.reason != 915
        )
    }

    private func messagePreview(_ message: VKConversationMessage?) -> String {
        let text = message?.body ?? message?.text ?? ""
        if !text.isEmpty { return text }
        guard let attachments = message?.attachments, !attachments.isEmpty else { return "" }

        return attachments.map { attachment in
            switch attachment.type?.lowercased() {
            case "photo": return "[Фотография]"
            case "video": return "[Видео]"
            case "audio": return "[Аудиозапись]"
            case "doc", "document": return "[Документ]"
            case "wall": return "[Запись]"
            case "market": return "[Товар]"
            case "poll": return "[Опрос]"
            case "sticker": return "[Стикер]"
            case "gift": return "[Подарок]"
            case "link": return "[Ссылка]"
            default: return "[Вложение]"
            }
        }.joined(separator: " ")
    }

    private func messageAuthorName(
        fromId: Int,
        profiles: [VKUserProfile],
        groups: [VKGroupProfile]
    ) -> String? {
        if fromId < 0, let group = groups.first(where: { $0.id == abs(fromId) }) {
            return group.name
        }

        guard let profile = profiles.first(where: { $0.id == abs(fromId) }) else {
            return nil
        }

        let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return firstNameOnly(name.isEmpty ? profile.screenName : name)
    }

    private func firstNameOnly(_ name: String?) -> String? {
        guard let name, !name.isEmpty else { return nil }
        return name.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
    }
}
