//
//  MessagesService.swift
//  OpenVK for iOS
//

import Foundation

protocol MessagesServiceProtocol {
    func cachedConversations() -> ConversationsPage?
    func offlineHistory(peerID: Int, offset: Int, count: Int, startMessageID: Int?, reverse: Bool) -> MessagesPage?
    func cacheConversations(_ page: ConversationsPage)
    func fetchConversations(offset: Int, count: Int, completion: @escaping (Result<ConversationsPage, Error>) -> Void)
    func fetchConversationsByIDs(_ peerIDs: [Int], completion: @escaping (Result<ConversationsPage, Error>) -> Void)
    func searchConversations(query: String, completion: @escaping (Result<ConversationsPage, Error>) -> Void)
    func cachedHistory(peerID: Int, offset: Int, count: Int, startMessageID: Int?, reverse: Bool) -> MessagesPage?
    func cacheHistory(page: MessagesPage, peerID: Int, offset: Int, count: Int, startMessageID: Int?, reverse: Bool)
    func fetchHistory(peerID: Int, offset: Int, count: Int, startMessageID: Int?, reverse: Bool, completion: @escaping (Result<MessagesPage, Error>) -> Void)
    func sendMessage(peerID: Int, text: String, replyTo: Int?, completion: @escaping (Result<Int, Error>) -> Void)
    func sendPhotos(peerID: Int, text: String, replyTo: Int?, photos: [Data], completion: @escaping (Result<Int, Error>) -> Void)
    func sendAttachments(peerID: Int, text: String, replyTo: Int?, photos: [Data], attachments: [String], completion: @escaping (Result<Int, Error>) -> Void)
    func sendSticker(peerID: Int, stickerID: Int, completion: @escaping (Result<Int, Error>) -> Void)
    func fetchStickerPacks(completion: @escaping (Result<[VKStickerPack], Error>) -> Void)
    func cachedStickerPacks() -> [VKStickerPack]?
    func setTyping(peerID: Int)
    func markAsRead(peerID: Int)
    func markConversationAsRead(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteConversation(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func leaveChat(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func editMessage(peerID: Int, messageID: Int, text: String, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteMessage(peerID: Int, messageID: Int, forAll: Bool, completion: @escaping (Result<Void, Error>) -> Void)
    func restoreMessage(peerID: Int, messageID: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func markMessageImportant(peerID: Int, messageID: Int, important: Bool, completion: @escaping (Result<Void, Error>) -> Void)
    func markConversationImportant(peerID: Int, important: Bool, completion: @escaping (Result<Void, Error>) -> Void)
    func pinMessage(peerID: Int, messageID: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func unpinMessage(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchPinnedMessage(peerID: Int, completion: @escaping (Result<ChatMessage?, Error>) -> Void)
}

extension MessagesServiceProtocol {
    func fetchPinnedMessage(peerID: Int, completion: @escaping (Result<ChatMessage?, Error>) -> Void) {
        completion(.success(nil))
    }
}

final class MessagesService: MessagesServiceProtocol {
    static let shared = MessagesService()

    private let client: APIClientProtocol
    private let offlineCacheLock = NSRecursiveLock()

    private var offlineScope: String {
        "messages.offline.v1.\(AppConfig.currentHost).\(AuthService.shared.currentUser?.uid ?? 0)"
    }

    func cachedConversations() -> ConversationsPage? {
        guard let data = CacheService.shared.cachedData(for: "\(offlineScope).conversations") else { return nil }
        return try? JSONDecoder().decode(ConversationsPage.self, from: data)
    }

    func cacheConversations(_ page: ConversationsPage) {
        guard let data = try? JSONEncoder().encode(page) else { return }
        CacheService.shared.cachePermanently(data: data, for: "\(offlineScope).conversations")
        ImageCache.shared.prefetch(page.conversations.compactMap(\.peer.avatarURL))
    }

    private func rememberConversations(_ conversations: [Conversation], totalCount: Int? = nil) {
        offlineCacheLock.lock()
        defer { offlineCacheLock.unlock() }
        let isCompleteList = totalCount.map { $0 <= conversations.count } ?? false
        let old = isCompleteList ? nil : cachedConversations()
        var byID = Dictionary((old?.conversations ?? []).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for conversation in conversations { byID[conversation.id] = conversation }
        let all = byID.values.sorted { $0.updatedAt > $1.updatedAt }
        cacheConversations(ConversationsPage(totalCount: max(totalCount ?? old?.totalCount ?? 0, all.count), conversations: all))
    }

    private func offlineMessages(peerID: Int) -> [ChatMessage] {
        guard let data = CacheService.shared.cachedData(for: "\(offlineScope).history.\(peerID)") else { return [] }
        return (try? JSONDecoder().decode([ChatMessage].self, from: data)) ?? []
    }

    private func rememberHistory(_ messages: [ChatMessage], peerID: Int) {
        offlineCacheLock.lock()
        defer { offlineCacheLock.unlock() }
        var byID = Dictionary(offlineMessages(peerID: peerID).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for message in messages where message.id > 0 { byID[message.id] = message }
        let saved = Array(byID.values.sorted { $0.id < $1.id }.suffix(2_000))
        guard let data = try? JSONEncoder().encode(saved) else { return }
        CacheService.shared.cachePermanently(data: data, for: "\(offlineScope).history.\(peerID)")
    }

    func offlineHistory(peerID: Int, offset: Int, count: Int, startMessageID: Int?, reverse: Bool) -> MessagesPage? {
        OfflineMessageHistory.page(messages: offlineMessages(peerID: peerID), offset: offset,
                                   count: count, startMessageID: startMessageID, reverse: reverse)
    }

    static func isConnectionFailure(_ error: Error) -> Bool {
        if case APIError.transport = error { return true }
        if case APIError.http(let status) = error { return status >= 500 }
        return error is URLError
    }

    init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    func cachedHistory(peerID: Int, offset: Int, count: Int, startMessageID: Int? = nil, reverse: Bool = false) -> MessagesPage? {
        guard let data = CacheService.shared.cachedData(for: historyCacheKey(peerID: peerID, offset: offset, count: count, startMessageID: startMessageID, reverse: reverse)),
              let cachedPage = try? JSONDecoder().decode(CachedMessagesPage.self, from: data),
              cachedPage.count >= cachedPage.messages.count,
              cachedPage.messages.allSatisfy({ $0.id > 0 }),
              zip(cachedPage.messages, cachedPage.messages.dropFirst()).allSatisfy({ $0.0.id < $0.1.id }) else {
            return nil
        }
        return MessagesPage(count: cachedPage.count, messages: cachedPage.messages)
    }

    func cachedStickerPacks() -> [VKStickerPack]? {
        guard let data = CacheService.shared.cachedData(for: "messages.sticker-packs"),
              let packs = try? JSONDecoder().decode([VKStickerPack].self, from: data) else {
            return nil
        }
        return packs
    }

    func fetchHistory(peerID: Int, offset: Int = 0, count: Int = 40, startMessageID: Int? = nil, reverse: Bool = false, completion: @escaping (Result<MessagesPage, Error>) -> Void) {
        let requestScope = offlineScope
        if !LongPollService.shared.hasNetworkConnection,
           let page = offlineHistory(peerID: peerID, offset: offset, count: count, startMessageID: startMessageID, reverse: reverse) {
            completion(.success(page))
            return
        }
        var parameters = ["peer_id": String(peerID), "offset": String(offset), "count": String(count), "extended": "1"]
        if let startMessageID { parameters["start_message_id"] = String(startMessageID) }
        if reverse { parameters["rev"] = "1" }
        client.call(
            method: "messages.getHistory",
            parameters: parameters,
            httpMethod: "GET",
            as: VKMessagesHistoryResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let profiles = response.profiles ?? []
                let items = (response.items ?? []).map { ChatMessage(message: $0, profiles: profiles) }
                let page = MessagesPage(count: response.count ?? items.count, messages: reverse ? items : Array(items.reversed()))
                if self.offlineScope == requestScope {
                    self.cacheHistory(page: page, peerID: peerID, offset: offset, count: count, startMessageID: startMessageID, reverse: reverse)
                }
                completion(.success(page))
            case .failure(let error):
                if Self.isConnectionFailure(error) { LongPollService.shared.recordConnectionFailure() }
                if self.offlineScope == requestScope, Self.isConnectionFailure(error),
                   let page = self.offlineHistory(peerID: peerID, offset: offset, count: count, startMessageID: startMessageID, reverse: reverse) {
                    completion(.success(page))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    func sendMessage(peerID: Int, text: String, replyTo: Int?, completion: @escaping (Result<Int, Error>) -> Void) {
        var parameters = ["peer_id": String(peerID), "message": text, "random_id": String(Int.random(in: 1...Int.max))]
        if let replyTo { parameters["reply_to"] = String(replyTo) }
        client.call(
            method: "messages.send",
            parameters: parameters,
            httpMethod: "POST",
            as: Int.self,
            completion: { result in completion(result.mapError { $0 as Error }) }
        )
    }

    func sendPhotos(peerID: Int, text: String, replyTo: Int?, photos: [Data], completion: @escaping (Result<Int, Error>) -> Void) {
        sendAttachments(peerID: peerID, text: text, replyTo: replyTo, photos: photos,
                        attachments: [], completion: completion)
    }

    func sendAttachments(peerID: Int, text: String, replyTo: Int?, photos: [Data], attachments: [String],
                         completion: @escaping (Result<Int, Error>) -> Void) {
        guard !photos.isEmpty || !attachments.isEmpty else {
            completion(.failure(APIError.invalidResponse))
            return
        }

        Task {
            do {
                var identifiers = attachments
                if !photos.isEmpty {
                    let server = try await client.call(
                        method: "photos.getMessagesUploadServer",
                        parameters: ["peer_id": String(peerID)],
                        httpMethod: "GET",
                        as: VKUploadServerResponse.self
                    )
                    guard let uploadURL = server.uploadUrl else { throw APIError.invalidResponse }

                    for (index, photo) in photos.enumerated() {
                        let uploadedData = try await client.upload(
                            urlString: uploadURL,
                            fileData: photo,
                            fileName: "message_\(index).jpg",
                            mimeType: "image/jpeg"
                        )
                        let uploaded = try JSONDecoder().decode(VKUploadResult.self, from: uploadedData)
                        let saved = try await client.call(
                            method: "photos.saveMessagesPhoto",
                            parameters: ["photo": uploaded.photo, "hash": uploaded.hash, "server": uploaded.server],
                            httpMethod: "POST",
                            as: [VKSavePhotoItem].self
                        )
                        guard let item = saved.first else { throw APIError.invalidResponse }
                        let key = item.accessKey.flatMap { $0.isEmpty ? nil : $0 }
                        let base = "photo\(item.ownerId)_\(item.id)"
                        identifiers.append(base + (key.map { "_\($0)" } ?? ""))
                    }
                }

                var parameters = [
                    "peer_id": String(peerID),
                    "message": text,
                    "attachment": identifiers.joined(separator: ","),
                    "random_id": String(Int.random(in: 1...Int.max))
                ]
                if let replyTo { parameters["reply_to"] = String(replyTo) }
                let messageID = try await client.call(
                    method: "messages.send", parameters: parameters,
                    httpMethod: "POST", as: Int.self
                )
                await MainActor.run { completion(.success(messageID)) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
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
            let packs = result.map { $0.items ?? [] }.mapError { $0 as Error }
            if case .success(let value) = packs {
                self.cacheStickerPacks(value)
            }
            completion(packs)
        }
    }

    func cacheHistory(page: MessagesPage, peerID: Int, offset: Int, count: Int, startMessageID: Int?, reverse: Bool = false) {
        guard let data = try? JSONEncoder().encode(CachedMessagesPage(count: page.count, messages: page.messages)) else { return }
        CacheService.shared.cachePermanently(data: data, for: historyCacheKey(peerID: peerID, offset: offset, count: count, startMessageID: startMessageID, reverse: reverse))
        rememberHistory(page.messages, peerID: peerID)
    }

    private func cacheStickerPacks(_ packs: [VKStickerPack]) {
        guard let data = try? JSONEncoder().encode(packs) else { return }
        CacheService.shared.cachePermanently(data: data, for: "messages.sticker-packs")
    }

    private func historyCacheKey(peerID: Int, offset: Int, count: Int, startMessageID: Int?, reverse: Bool) -> String {
        let userID = AuthService.shared.currentUser?.uid ?? 0
        let base = "messages.history.\(AppConfig.currentHost).\(userID).\(peerID).\(offset).\(count)"
        let anchored = startMessageID.map { "\(base).from.\($0)" } ?? base
        return reverse ? "\(anchored).rev" : anchored
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

    func editMessage(peerID: Int, messageID: Int, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.edit",
            parameters: ["peer_id": String(peerID), "message_id": String(messageID), "message": text],
            httpMethod: "POST",
            as: Int.self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func deleteMessage(peerID: Int, messageID: Int, forAll: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.delete",
            parameters: [
                "peer_id": String(peerID),
                "message_ids": String(messageID),
                "delete_for_all": forAll ? "1" : "0"
            ],
            httpMethod: "POST",
            as: [String: Int].self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func searchConversations(
        query: String,
        completion: @escaping (Result<ConversationsPage, Error>) -> Void
    ) {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            completion(.success(ConversationsPage(totalCount: 0, conversations: [])))
            return
        }

        let requestScope = offlineScope
        if !LongPollService.shared.hasNetworkConnection, let page = savedSearch(query: value) {
            completion(.success(page))
            return
        }
        client.call(
            method: "messages.searchConversations",
            parameters: [
                "q": value,
                "extended": "1",
                "fields": "id,first_name,last_name,screen_name,photo_100,photo_200,online,last_seen,verified"
            ],
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
                if self.offlineScope == requestScope { self.rememberConversations(conversations) }
                completion(.success(ConversationsPage(
                    totalCount: response.count ?? conversations.count,
                    conversations: conversations
                )))
            case .failure(let error):
                if Self.isConnectionFailure(error) { LongPollService.shared.recordConnectionFailure() }
                if self.offlineScope == requestScope, Self.isConnectionFailure(error), let page = self.savedSearch(query: value) {
                    completion(.success(page))
                } else { completion(.failure(error)) }
            }
        }
    }

    func restoreMessage(peerID: Int, messageID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.restore",
            parameters: ["peer_id": String(peerID), "message_id": String(messageID)],
            httpMethod: "POST",
            as: Int.self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func markMessageImportant(peerID: Int, messageID: Int, important: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.markAsImportant",
            parameters: [
                "peer_id": String(peerID),
                "message_ids": String(messageID),
                "important": important ? "1" : "0"
            ],
            httpMethod: "POST",
            as: [Int].self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func markConversationImportant(peerID: Int, important: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.markAsImportantConversation",
            parameters: ["peer_id": String(peerID), "important": important ? "1" : "0"],
            httpMethod: "POST",
            as: Int.self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func pinMessage(peerID: Int, messageID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.pin",
            parameters: ["peer_id": String(peerID), "message_id": String(messageID)],
            httpMethod: "POST",
            as: VKHistoryMessage.self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func unpinMessage(peerID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        client.call(
            method: "messages.unpin",
            parameters: ["peer_id": String(peerID)],
            httpMethod: "POST",
            as: Int.self
        ) { result in
            completion(result.map { _ in () }.mapError { $0 as Error })
        }
    }

    func fetchConversationsByIDs(
        _ peerIDs: [Int],
        completion: @escaping (Result<ConversationsPage, Error>) -> Void
    ) {
        guard !peerIDs.isEmpty else {
            completion(.success(ConversationsPage(totalCount: 0, conversations: [])))
            return
        }
        let requestScope = offlineScope
        let saved = cachedConversations().map { page in
            let items = page.conversations.filter { peerIDs.contains($0.id) }
            return ConversationsPage(totalCount: items.count, conversations: items)
        }
        if !LongPollService.shared.hasNetworkConnection, let saved {
            completion(.success(saved))
            return
        }
        client.call(
            method: "messages.getConversationsById",
            parameters: [
                "peer_ids": peerIDs.map(String.init).joined(separator: ","),
                "extended": "1",
                "fields": "id,first_name,last_name,screen_name,photo_100,photo_200,online,last_seen,verified"
            ],
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
                if self.offlineScope == requestScope { self.rememberConversations(conversations) }
                completion(.success(ConversationsPage(
                    totalCount: response.count ?? conversations.count,
                    conversations: conversations
                )))
            case .failure(let error):
                if Self.isConnectionFailure(error) { LongPollService.shared.recordConnectionFailure() }
                if self.offlineScope == requestScope, Self.isConnectionFailure(error), let saved {
                    completion(.success(saved))
                } else { completion(.failure(error)) }
            }
        }
    }

    func fetchPinnedMessage(
        peerID: Int,
        completion: @escaping (Result<ChatMessage?, Error>) -> Void
    ) {
        client.call(
            method: "messages.getConversationsById",
            parameters: ["peer_ids": String(peerID), "extended": "1"],
            httpMethod: "GET",
            as: VKConversationsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                guard let pinned = response.items?.first?.conversation.chatSettings?.pinnedMessage,
                      let id = pinned.id, id > 0 else {
                    completion(.success(nil))
                    return
                }
                var message = ChatMessage(message: pinned, profiles: response.profiles ?? [])
                message.isPinned = true
                completion(.success(message))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchConversations(
        offset: Int = 0,
        count: Int = 30,
        completion: @escaping (Result<ConversationsPage, Error>) -> Void
    ) {
        let requestScope = offlineScope
        if !LongPollService.shared.hasNetworkConnection, let saved = savedConversations(offset: offset, count: count) {
            completion(.success(saved))
            return
        }
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
                if self.offlineScope == requestScope {
                    self.rememberConversations(conversations, totalCount: response.count)
                }
                completion(.success(ConversationsPage(
                    totalCount: response.count ?? conversations.count,
                    conversations: conversations
                )))
            case .failure(let error):
                if Self.isConnectionFailure(error) { LongPollService.shared.recordConnectionFailure() }
                if self.offlineScope == requestScope, Self.isConnectionFailure(error),
                   let saved = self.savedConversations(offset: offset, count: count) {
                    completion(.success(saved))
                } else { completion(.failure(error)) }
            }
        }
    }

    private func savedConversations(offset: Int, count: Int) -> ConversationsPage? {
        guard let saved = cachedConversations() else { return nil }
        return ConversationsPage(totalCount: saved.conversations.count,
                                 conversations: Array(saved.conversations.dropFirst(max(0, offset)).prefix(max(0, count))))
    }

    private func savedSearch(query: String) -> ConversationsPage? {
        guard let saved = cachedConversations() else { return nil }
        let matches = saved.conversations.filter {
            $0.peer.displayName.localizedCaseInsensitiveContains(query)
                || $0.lastMessage.localizedCaseInsensitiveContains(query)
        }
        return ConversationsPage(totalCount: matches.count, conversations: matches)
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
            isChatMember: !["left", "kicked", "out"].contains(item.conversation.chatSettings?.state?.lowercased())
                && item.conversation.canWrite?.allowed != false
                && ![915, 916, 917].contains(item.conversation.canWrite?.reason ?? 0),
            chatMemberCount: item.conversation.chatSettings?.membersCount,
            inReadMessageID: item.conversation.inRead ?? 0,
            outReadMessageID: item.conversation.outRead ?? 0,
            inReadConversationMessageID: item.conversation.inReadCmid ?? 0,
            outReadConversationMessageID: item.conversation.outReadCmid ?? 0,
            lastConversationMessageID: item.conversation.lastConversationMessageId ?? 0,
            isImportant: item.conversation.important == true,
            isUnanswered: item.conversation.unanswered == true
        )
    }

    private func messagePreview(_ message: VKConversationMessage?) -> String {
        let text = message?.body ?? message?.text ?? ""
        if !text.isEmpty { return text }
        if !(message?.fwdMessages ?? []).isEmpty { return "[Пересланное сообщение]" }
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

private struct CachedMessagesPage: Codable {
    let count: Int
    let messages: [ChatMessage]
}

// The offline snapshot contains downloaded messages only. Counts describe saved
// messages, so pagination ends at the local boundary without looping on the API.
enum OfflineMessageHistory {
    static func page(messages: [ChatMessage], offset: Int, count: Int,
                     startMessageID: Int?, reverse: Bool) -> MessagesPage? {
        guard !messages.isEmpty, count > 0 else { return nil }
        if let anchor = startMessageID {
            guard let index = messages.firstIndex(where: { $0.id == anchor }) else { return nil }
            if reverse {
                let start = min(messages.count, max(0, index + offset))
                let end = min(messages.count, start + count)
                return MessagesPage(count: messages.count - index, messages: Array(messages[start..<end]))
            }
            let end = min(messages.count, max(0, index + 1 - offset))
            let start = max(0, end - count)
            return MessagesPage(count: end + (offset > 0 ? 1 : 0), messages: Array(messages[start..<end]))
        }
        let end = max(0, messages.count - max(0, offset))
        let start = max(0, end - count)
        return MessagesPage(count: messages.count, messages: Array(messages[start..<end]))
    }
}
