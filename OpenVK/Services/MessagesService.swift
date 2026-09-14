//
//  MessagesService.swift
//  OpenVK for iOS
//

import Foundation

protocol MessagesServiceProtocol {
    func fetchConversations(offset: Int, count: Int, completion: @escaping (Result<ConversationsPage, Error>) -> Void)
}

final class MessagesService: MessagesServiceProtocol {
    static let shared = MessagesService()

    private let client: APIClientProtocol

    private init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
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

        return Conversation(
            id: peer.id,
            peer: peerUser,
            lastMessage: message?.body ?? message?.text ?? "",
            lastMessageAuthorName: authorName,
            lastMessageOutgoing: message?.out == 1,
            updatedAt: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : Date(),
            unreadCount: item.conversation.unreadCount ?? 0,
            lastMessageId: item.conversation.lastMessageId ?? message?.id ?? 0,
            isChat: isChat
        )
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
        return name.isEmpty ? profile.screenName : name
    }
}
