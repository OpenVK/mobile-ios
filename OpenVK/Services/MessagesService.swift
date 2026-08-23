//
//  MessagesService.swift
//  OpenVK for iOS
//

import Foundation

protocol MessagesServiceProtocol {
    func fetchConversations(offset: Int, count: Int, filter: String?, groupId: Int?, completion: @escaping (Result<[Conversation], Error>) -> Void)
    func fetchConversationsById(peerIds: [Int], groupId: Int?, completion: @escaping (Result<[Conversation], Error>) -> Void)
    func searchConversations(query: String, groupId: Int?, completion: @escaping (Result<[Conversation], Error>) -> Void)
    func fetchMessages(peerID: Int, offset: Int, count: Int, startMessageId: Int?, rev: Int?, groupId: Int?, completion: @escaping (Result<[Message], Error>) -> Void)
    func send(text: String, to peerID: Int, attachments: String?, replyTo: Int?, stickerId: Int?, groupId: Int?, completion: @escaping (Result<Int, Error>) -> Void)
    func edit(peerID: Int, messageID: Int, newText: String, attachments: String?, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func delete(peerID: Int, messageIDs: [Int], deleteForAll: Bool, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func restore(peerID: Int, messageID: Int, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func markAsRead(peerID: Int, startMessageId: Int?, messageIDs: [Int]?, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func markAsImportant(messageIDs: [Int], important: Bool, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func markAsImportantConversation(peerID: Int, important: Bool, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func markAsAnsweredConversation(peerID: Int, answered: Bool, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func pin(peerID: Int, messageID: Int, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func unpin(peerID: Int, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func setActivity(peerID: Int, type: String, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func createChat(title: String, userIds: [Int], groupId: Int?, completion: @escaping (Result<Int, Error>) -> Void)
    func addChatUser(peerID: Int, userIds: [Int], groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func removeChatUser(peerID: Int, userId: Int, groupId: Int?, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchChatMembers(peerID: Int, groupId: Int?, completion: @escaping (Result<[ChatMember], Error>) -> Void)
    func fetchLongPollServer(needPts: Bool, groupId: Int?, completion: @escaping (Result<VKLongPollServerResponse, Error>) -> Void)
    func fetchStickerPacks(completion: @escaping (Result<[StickerPack], Error>) -> Void)
    func buyStickerPack(packId: Int, completion: @escaping (Result<Void, Error>) -> Void)

    // Обратная совместимость с базовыми вызовами
    func fetchConversations(offset: Int, count: Int, completion: @escaping (Result<[Conversation], Error>) -> Void)
    func fetchMessages(peerID: Int, offset: Int, count: Int, completion: @escaping (Result<[Message], Error>) -> Void)
    func send(text: String, to peerID: Int, completion: @escaping (Result<Int, Error>) -> Void)
    func edit(messageID: Int, newText: String, completion: @escaping (Result<Void, Error>) -> Void)
    func delete(messageIDs: [Int], completion: @escaping (Result<Void, Error>) -> Void)
}

extension MessagesServiceProtocol {
    func fetchConversations(offset: Int, count: Int, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        fetchConversations(offset: offset, count: count, filter: nil, groupId: nil, completion: completion)
    }

    func fetchMessages(peerID: Int, offset: Int, count: Int, completion: @escaping (Result<[Message], Error>) -> Void) {
        fetchMessages(peerID: peerID, offset: offset, count: count, startMessageId: nil, rev: nil, groupId: nil, completion: completion)
    }

    func send(text: String, to peerID: Int, completion: @escaping (Result<Int, Error>) -> Void) {
        send(text: text, to: peerID, attachments: nil, replyTo: nil, stickerId: nil, groupId: nil, completion: completion)
    }

    func edit(messageID: Int, newText: String, completion: @escaping (Result<Void, Error>) -> Void) {
        edit(peerID: 0, messageID: messageID, newText: newText, attachments: nil, groupId: nil, completion: completion)
    }

    func delete(messageIDs: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
        delete(peerID: 0, messageIDs: messageIDs, deleteForAll: true, groupId: nil, completion: completion)
    }
}

final class MessagesService: MessagesServiceProtocol {

    static let shared = MessagesService()
    private let client: APIClientProtocol

    init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }


    func fetchConversations(
        offset: Int = 0,
        count: Int = 20,
        filter: String? = nil,
        groupId: Int? = nil,
        completion: @escaping (Result<[Conversation], Error>) -> Void
    ) {
        var params: [String: String] = [
            "offset": "\(offset)",
            "count": "\(count)",
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,photo_200,online,last_seen,verified,name"
        ]
        if let filter = filter, !filter.isEmpty {
            params["filter"] = filter
        }
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.getConversations", parameters: params, httpMethod: "GET", as: VKConversationsResponse.self) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let conversations = self.mapConversationsResponse(response)
                completion(.success(conversations))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchConversationsById(
        peerIds: [Int],
        groupId: Int? = nil,
        completion: @escaping (Result<[Conversation], Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_ids": peerIds.map(String.init).joined(separator: ","),
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,photo_200,online,last_seen,verified,name"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.getConversationsById", parameters: params, httpMethod: "GET", as: VKConversationsResponse.self) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let conversations = self.mapConversationsResponse(response)
                completion(.success(conversations))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func searchConversations(
        query: String,
        groupId: Int? = nil,
        completion: @escaping (Result<[Conversation], Error>) -> Void
    ) {
        var params: [String: String] = [
            "q": query,
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,photo_200,online,last_seen,verified,name"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.searchConversations", parameters: params, httpMethod: "GET", as: VKConversationsResponse.self) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let conversations = self.mapConversationsResponse(response)
                completion(.success(conversations))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }


    func fetchMessages(
        peerID: Int,
        offset: Int = 0,
        count: Int = 20,
        startMessageId: Int? = nil,
        rev: Int? = nil,
        groupId: Int? = nil,
        completion: @escaping (Result<[Message], Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "offset": "\(offset)",
            "count": "\(count)",
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,photo_200,online,name"
        ]
        if let startMessageId = startMessageId, startMessageId > 0 {
            params["start_message_id"] = "\(startMessageId)"
        }
        if let rev = rev {
            params["rev"] = "\(rev)"
        }
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.getHistory", parameters: params, httpMethod: "GET", as: VKMessageHistoryResponse.self) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let profiles = response.profiles ?? []
                let groups = response.groups ?? []
                let messages = (response.items ?? []).map { self.mapMessageItem($0, profiles: profiles, groups: groups) }
                completion(.success(messages))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }


    func send(
        text: String,
        to peerID: Int,
        attachments: String? = nil,
        replyTo: Int? = nil,
        stickerId: Int? = nil,
        groupId: Int? = nil,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "message": text,
            "random_id": "\(Int.random(in: 1...2147483647))"
        ]
        if let attachments = attachments, !attachments.isEmpty {
            params["attachment"] = attachments
        }
        if let replyTo = replyTo, replyTo > 0 {
            params["reply_to"] = "\(replyTo)"
        }
        if let stickerId = stickerId, stickerId > 0 {
            params["sticker_id"] = "\(stickerId)"
        }
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.send", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success(let messageID):
                completion(.success(messageID))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func edit(
        peerID: Int,
        messageID: Int,
        newText: String,
        attachments: String? = nil,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "message_id": "\(messageID)",
            "message": newText
        ]
        if let attachments = attachments {
            params["attachment"] = attachments
        }
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.edit", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func delete(
        peerID: Int,
        messageIDs: [Int],
        deleteForAll: Bool = true,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "message_ids": messageIDs.map(String.init).joined(separator: ","),
            "delete_for_all": deleteForAll ? "1" : "0"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.delete", parameters: params, httpMethod: "POST", as: [String: Int].self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func restore(
        peerID: Int,
        messageID: Int,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "message_id": "\(messageID)"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.restore", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func markAsRead(
        peerID: Int,
        startMessageId: Int? = nil,
        messageIDs: [Int]? = nil,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)"
        ]
        if let startMessageId = startMessageId, startMessageId > 0 {
            params["start_message_id"] = "\(startMessageId)"
        }
        if let messageIDs = messageIDs, !messageIDs.isEmpty {
            params["message_ids"] = messageIDs.map(String.init).joined(separator: ",")
        }
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.markAsRead", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func markAsImportant(
        messageIDs: [Int],
        important: Bool = true,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "message_ids": messageIDs.map(String.init).joined(separator: ","),
            "important": important ? "1" : "0"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.markAsImportant", parameters: params, httpMethod: "POST", as: [Int].self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func markAsImportantConversation(
        peerID: Int,
        important: Bool = true,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "important": important ? "1" : "0"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.markAsImportantConversation", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func markAsAnsweredConversation(
        peerID: Int,
        answered: Bool = true,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "answered": answered ? "1" : "0"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.markAsAnsweredConversation", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func pin(
        peerID: Int,
        messageID: Int,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "message_id": "\(messageID)"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.pin", parameters: params, httpMethod: "POST", as: [String: String].self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func unpin(
        peerID: Int,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.unpin", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func setActivity(
        peerID: Int,
        type: String = "typing",
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "type": type
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.setActivity", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func createChat(
        title: String,
        userIds: [Int],
        groupId: Int? = nil,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        var params: [String: String] = [
            "title": title,
            "user_ids": userIds.map(String.init).joined(separator: ",")
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.createChat", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success(let chatId):
                completion(.success(chatId))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func addChatUser(
        peerID: Int,
        userIds: [Int],
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "user_id": userIds.map(String.init).joined(separator: ",")
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.addChatUser", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func removeChatUser(
        peerID: Int,
        userId: Int,
        groupId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "user_id": "\(userId)"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.removeChatUser", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchChatMembers(
        peerID: Int,
        groupId: Int? = nil,
        completion: @escaping (Result<[ChatMember], Error>) -> Void
    ) {
        var params: [String: String] = [
            "peer_id": "\(peerID)",
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,photo_200,online,last_seen,verified"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.getConversationMembers", parameters: params, httpMethod: "GET", as: VKConversationMembersResponse.self) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let profiles = response.profiles ?? []
                let members = (response.items ?? []).compactMap { item -> ChatMember? in
                    guard let memberId = item.memberId else { return nil }
                    let userProfile = profiles.first(where: { $0.id == memberId })
                    let user = userProfile.flatMap { self.mapUserProfile($0) }
                    return ChatMember(
                        userId: memberId,
                        invitedBy: item.invitedBy,
                        joinDate: item.joinDate.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                        isAdmin: item.isAdmin == true,
                        canKick: item.canKick == true,
                        user: user
                    )
                }
                completion(.success(members))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchLongPollServer(
        needPts: Bool = true,
        groupId: Int? = nil,
        completion: @escaping (Result<VKLongPollServerResponse, Error>) -> Void
    ) {
        var params: [String: String] = [
            "need_pts": needPts ? "1" : "0",
            "version": "2"
        ]
        if let groupId = groupId, groupId > 0 {
            params["group_id"] = "\(groupId)"
        }

        client.call(method: "messages.getLongPollServer", parameters: params, httpMethod: "GET", as: VKLongPollServerResponse.self) { result in
            switch result {
            case .success(let response):
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchStickerPacks(completion: @escaping (Result<[StickerPack], Error>) -> Void) {
        client.call(method: "stickers.get", parameters: [:], httpMethod: "GET", as: VKStickersResponse.self) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let packs = (response.items ?? []).map { self.mapStickerPack($0) }
                completion(.success(packs))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func buyStickerPack(packId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let params: [String: String] = ["stickerpack_id": "\(packId)"]
        client.call(method: "stickers.buy", parameters: params, httpMethod: "POST", as: [String: Int].self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func mapConversationsResponse(_ response: VKConversationsResponse) -> [Conversation] {
        let profiles = response.profiles ?? []
        let groups = response.groups ?? []
        let chats = response.chats ?? []

        return (response.items ?? []).compactMap { item -> Conversation? in
            guard let conv = item.conversation, let peerDto = conv.peer, let peerID = peerDto.id else {
                return nil
            }
            let peerType = peerDto.type ?? (peerID >= 2000000000 ? "chat" : (peerID < 0 ? "group" : "user"))
            let peer: Peer

            if peerID >= 2000000000 || peerType == "chat" {
                let chatId = peerID > 2000000000 ? peerID - 2000000000 : peerID
                let chatSettings = conv.chatSettings
                let chatInfo = chats.first(where: { $0.id == peerID || $0.id == chatId })

                let title = chatSettings?.title ?? chatInfo?.title ?? "Беседа №\(chatId)"
                let photoStr = chatSettings?.photo?.photo200 ?? chatSettings?.photo?.photo100 ?? chatInfo?.photo200 ?? chatInfo?.photo100
                let photoURL = photoStr.flatMap { URL(string: $0) }
                let membersCount = chatSettings?.membersCount ?? chatInfo?.membersCount ?? 0

                peer = Peer(
                    id: peerID,
                    type: .chat,
                    title: title,
                    avatarURL: photoURL,
                    membersCount: membersCount
                )
            } else if peerID < 0 || peerType == "group" {
                let groupId = abs(peerID)
                let groupProfile = groups.first(where: { $0.id == groupId })
                let community = groupProfile.flatMap { self.mapGroupProfile($0) }
                let title = community?.name ?? "Сообщество \(groupId)"
                let avatarURL = community?.photo100.flatMap { URL(string: $0) }

                peer = Peer(
                    id: peerID,
                    type: .group,
                    title: title,
                    avatarURL: avatarURL,
                    isOfficial: community?.isOfficial,
                    community: community
                )
            } else {
                let userProfile = profiles.first(where: { $0.id == peerID })
                let user = userProfile.flatMap { self.mapUserProfile($0) }
                let name = user?.displayName ?? "Пользователь \(peerID)"
                let avatarURL = user?.avatarURL

                peer = Peer(
                    id: peerID,
                    type: .user,
                    title: name,
                    avatarURL: avatarURL,
                    isOnline: user?.isOnline,
                    onlinePlatform: user?.onlinePlatform,
                    isOfficial: user?.isOfficial,
                    user: user
                )
            }

            let myId = AuthService.shared.currentUser?.uid ?? 0
            let lastFromId = item.lastMessage?.fromId ?? 0
            let isLastOut = (item.lastMessage?.out == 1) || (myId > 0 && lastFromId == myId)

            var lastMessageText = ""
            if let text = item.lastMessage?.text ?? item.lastMessage?.body, !text.isEmpty {
                lastMessageText = text
            } else if let att = item.lastMessage?.attachments?.first, let attType = att.type {
                lastMessageText = self.attachmentPlaceholder(attType)
            } else if item.lastMessage?.attachments?.contains(where: { $0.type == "sticker" || $0.sticker != nil }) == true {
                lastMessageText = "[Стикер]"
            } else if let reply = item.lastMessage?.replyMessage {
                lastMessageText = reply.text?.isEmpty == false ? "Ответ: \(reply.text!)" : "[Ответ]"
            }

            let dateInt = item.lastMessage?.date ?? 0
            let date = dateInt > 0 ? Date(timeIntervalSince1970: TimeInterval(dateInt)) : Date()

            var chatSettingsDomain: ChatSettings? = nil
            if let cs = conv.chatSettings {
                let photoURL = (cs.photo?.photo200 ?? cs.photo?.photo100).flatMap { URL(string: $0) }
                let pinnedDomain = cs.pinnedMessage.map { self.mapMessageItem($0, profiles: profiles, groups: groups) }
                chatSettingsDomain = ChatSettings(
                    id: cs.id ?? peerID,
                    title: cs.title ?? peer.title,
                    membersCount: cs.membersCount ?? (peer.membersCount ?? 0),
                    adminId: cs.adminId ?? 0,
                    photoURL: photoURL,
                    acl: cs.acl,
                    pinnedMessage: pinnedDomain
                )
            }

            let inRead = conv.inRead ?? 0
            let outRead = conv.outRead ?? 0
            let lastMsgId = conv.lastMessageId ?? (item.lastMessage?.id ?? 0)
            var unreadCount = conv.unreadCount ?? 0
            if unreadCount == 0 && !isLastOut && inRead < lastMsgId && lastMsgId > 0 {
                unreadCount = 1
            }

            return Conversation(
                peer: peer,
                lastMessage: lastMessageText,
                lastMessageOutgoing: isLastOut,
                updatedAt: date,
                unreadCount: unreadCount,
                lastMessageId: lastMsgId,
                inRead: inRead,
                outRead: outRead,
                chatSettings: chatSettingsDomain,
                isImportant: conv.important == true,
                isAnswered: conv.answered == true,
                isMuted: false
            )
        }
    }

    private func mapMessageItem(
        _ item: VKIMMessageItem,
        profiles: [VKUserProfile],
        groups: [VKGroupProfile]
    ) -> Message {
        let myId = AuthService.shared.currentUser?.uid ?? 0
        let fromId = item.fromId ?? (item.out == 1 ? myId : (item.peerId ?? 0))
        let isOut = (item.out == 1) || (myId > 0 && fromId == myId)
        let direction: Message.Direction = isOut ? .outgoing : .incoming
        let text = item.text ?? item.body ?? ""
        let date = Date(timeIntervalSince1970: TimeInterval(item.date ?? 0))

        var senderName: String? = nil
        var senderAvatarURL: URL? = nil

        if fromId > 0 {
            if let prof = profiles.first(where: { $0.id == fromId }) {
                senderName = "\(prof.firstName ?? "") \(prof.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                senderAvatarURL = (prof.photo200 ?? prof.photo100).flatMap { URL(string: $0) }
            }
        } else if fromId < 0 {
            if let grp = groups.first(where: { $0.id == abs(fromId) }) {
                senderName = grp.name ?? "Сообщество"
                senderAvatarURL = (grp.photo200 ?? grp.photo100).flatMap { URL(string: $0) }
            }
        }

        let attachments = self.mapAttachments(item.attachments ?? [])

        var stickerDomain: Sticker? = nil
        if let stickerAtt = item.attachments?.first(where: { $0.type == "sticker" })?.sticker,
           let stickerId = stickerAtt.stickerId {
            if let bestImg = stickerAtt.images?.last, let urlStr = bestImg.url, let imgUrl = URL(string: urlStr) {
                stickerDomain = Sticker(
                    id: stickerId,
                    packId: stickerAtt.productId ?? 0,
                    imageURL: imgUrl,
                    width: bestImg.width ?? 128,
                    height: bestImg.height ?? 128
                )
            }
        }

        var replyDomain: MessageReply? = nil
        if let rep = item.replyMessage {
            var repSenderName = "Сообщение"
            let repFromId = rep.fromId ?? 0
            if repFromId > 0, let p = profiles.first(where: { $0.id == repFromId }) {
                repSenderName = "\(p.firstName ?? "") \(p.lastName ?? "")".trimmingCharacters(in: .whitespaces)
            } else if repFromId < 0, let g = groups.first(where: { $0.id == abs(repFromId) }) {
                repSenderName = g.name ?? "Сообщество"
            }
            replyDomain = MessageReply(
                id: rep.id ?? 0,
                fromId: repFromId,
                senderName: repSenderName,
                text: rep.text ?? "",
                attachments: self.mapAttachments(rep.attachments ?? [])
            )
        }

        return Message(
            id: item.id ?? 0,
            peerId: item.peerId ?? item.userId ?? fromId,
            fromId: fromId,
            text: text,
            date: date,
            direction: direction,
            isRead: false,
            attachments: attachments,
            replyMessage: replyDomain,
            isPinned: item.isPinned == true,
            isImportant: item.isImportant == true,
            isDeleted: item.isDeleted == true,
            isEdited: item.isEdited == true,
            sticker: stickerDomain,
            senderName: senderName,
            senderAvatarURL: senderAvatarURL
        )
    }

    private func mapAttachments(_ items: [VKIMAttachmentItem]) -> [Attachment] {
        var result: [Attachment] = []
        for att in items {
            switch att.type {
            case "photo":
                if let p = att.photo {
                    let urlStr = p.photo1280 ?? p.photo807 ?? p.photo604 ?? p.photo130 ?? p.sizes?.last?.url ?? ""
                    if !urlStr.isEmpty {
                        result.append(.remoteImage(
                            url: urlStr,
                            id: p.id,
                            ownerID: p.ownerId,
                            likesCount: 0,
                            commentsCount: 0,
                            repostsCount: 0,
                            isLiked: false
                        ))
                    }
                }
            case "video":
                if let v = att.video {
                    let cover = v.photo800 ?? v.photo320 ?? ""
                    result.append(.remoteVideo(
                        title: v.title ?? "Видеозапись",
                        duration: formatDuration(v.duration ?? 0),
                        imageURL: cover,
                        videoURL: v.player,
                        id: v.id,
                        ownerID: v.ownerId,
                        files: nil,
                        likesCount: 0,
                        commentsCount: 0,
                        repostsCount: 0,
                        isLiked: false
                    ))
                }
            case "audio":
                if let a = att.audio {
                    result.append(.audio(
                        artist: a.artist ?? "Неизвестный исполнитель",
                        title: a.title ?? "Аудиозапись",
                        duration: formatDuration(a.duration ?? 0)
                    ))
                }
            case "doc":
                if let d = att.doc {
                    result.append(.document(
                        title: d.title ?? "Документ",
                        ext: d.ext ?? "file",
                        size: formatFileSize(d.size ?? 0),
                        url: d.url ?? ""
                    ))
                }
            case "wall":
                if let w = att.wall {
                    result.append(.note(
                        title: "Запись на стене",
                        content: w.text ?? ""
                    ))
                }
            default:
                break
            }
        }
        return result
    }

    private func mapStickerPack(_ item: VKStickerPackDTO) -> StickerPack {
        let packId = item.id ?? 0
        let stickers = (item.stickers ?? []).compactMap { st -> Sticker? in
            guard let stickerId = st.stickerId,
                  let bestImg = st.images?.last,
                  let urlStr = bestImg.url,
                  let url = URL(string: urlStr) else { return nil }
            return Sticker(
                id: stickerId,
                packId: st.productId ?? packId,
                imageURL: url,
                width: bestImg.width ?? 128,
                height: bestImg.height ?? 128
            )
        }

        return StickerPack(
            id: packId,
            title: item.title ?? "Стикеры",
            author: item.author,
            description: item.description,
            iconURL: item.icon.flatMap { URL(string: $0) },
            isPurchased: item.purchased == 1,
            isFree: item.free == 1,
            price: item.price ?? 0,
            stickers: stickers
        )
    }

    private func mapUserProfile(_ profile: VKUserProfile) -> User {
        let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")".trimmingCharacters(in: .whitespaces)
        return User(
            uid: profile.id,
            username: profile.screenName ?? "id\(profile.id)",
            displayName: name.isEmpty ? "Пользователь" : name,
            avatarURL: (profile.photo200 ?? profile.photo100).flatMap { URL(string: $0) },
            isOnline: profile.online == 1,
            onlinePlatform: profile.lastSeen?.platformName,
            isOfficial: profile.verified == 1
        )
    }

    private func mapGroupProfile(_ group: VKGroupProfile) -> Community {
        return Community(
            vkID: group.id,
            name: group.name ?? "Сообщество",
            screenName: group.screenName ?? "club\(group.id)",
            photo100: group.photo200 ?? group.photo100,
            memberCount: 0,
            isOfficial: group.verified == 1,
            isAdmin: group.isAdmin == true,
            canPost: group.canPost == true,
            canSuggest: group.canSuggest == true
        )
    }

    private func attachmentPlaceholder(_ type: String) -> String {
        switch type {
        case "photo": return "[Фотография]"
        case "video": return "[Видеозапись]"
        case "audio": return "[Аудиозапись]"
        case "doc": return "[Документ]"
        case "wall": return "[Запись со стены]"
        case "sticker": return "[Стикер]"
        case "gift": return "[Подарок]"
        default: return "[Вложение]"
        }
    }

    private func formatDuration(_ duration: Int) -> String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatFileSize(_ size: Int) -> String {
        if size > 1024 * 1024 {
            return String(format: "%.1f МБ", Double(size) / (1024.0 * 1024.0))
        } else if size > 1024 {
            return String(format: "%.1f КБ", Double(size) / 1024.0)
        } else {
            return "\(size) Б"
        }
    }
}
