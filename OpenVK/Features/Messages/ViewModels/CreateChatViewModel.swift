//
//  CreateChatViewModel.swift
//  OpenVK for iOS
//

import Foundation
import SwiftUI

final class CreateChatViewModel: ObservableObject {
    @Published private(set) var friends: [User] = []
    @Published private(set) var globalUsers: [User] = []
    @Published private(set) var isLoadingFriends = false
    @Published private(set) var isLoadingGlobal = false
    @Published private(set) var globalHasMore = false
    @Published var errorMessage: String?

    private let friendsPageSize = 100
    private let globalPageSize = 30
    private var friendsOffset = 0
    private var friendsTotal = 0
    private var searchGeneration = 0

    var groupedFriends: [(String, [User])] {
        let groups = Dictionary(grouping: friends) { user in
            sectionLetter(for: user.displayName)
        }
        return groups.keys.sorted { lhs, rhs in
            if lhs == "#" { return false }
            if rhs == "#" { return true }
            return lhs < rhs
        }.map { ($0, groups[$0] ?? []) }
    }

    private func sectionLetter(for name: String) -> String {
        guard let scalar = name.uppercased().unicodeScalars.first else { return "#" }
        let value = scalar.value
        let isLatin = (65...90).contains(value)
        let isCyrillic = (1025...1071).contains(value)
        return isLatin || isCyrillic ? String(scalar) : "#"
    }

    func loadFriends() {
        guard !isLoadingFriends, friends.isEmpty else { return }

        isLoadingFriends = true
        errorMessage = nil
        friendsOffset = 0
        friendsTotal = 0
        loadFriendsPage()
    }

    func filteredFriends(for query: String) -> [User] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return friends }

        let normalized = trimmed.lowercased()
        return friends.filter {
            $0.displayName.lowercased().contains(normalized) ||
                $0.username.lowercased().contains(normalized)
        }
    }

    func searchGlobal(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchGeneration += 1
        let generation = searchGeneration
        globalUsers = []
        globalHasMore = false

        guard !trimmed.isEmpty else { return }

        isLoadingGlobal = true
        SearchService.shared.searchUsers(
            query: trimmed,
            sort: 4,
            onlyOnline: false,
            offset: 0,
            count: globalPageSize
        ) { [weak self] users, total in
            DispatchQueue.main.async {
                guard let self, generation == self.searchGeneration else { return }
                self.globalUsers = users
                self.globalHasMore = users.count < total && !users.isEmpty
                self.isLoadingGlobal = false
            }
        }
    }

    func loadMoreGlobalIfNeeded(after user: User, query: String) {
        guard user.id == globalUsers.last?.id,
              globalHasMore,
              !isLoadingGlobal,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoadingGlobal = true
        let generation = searchGeneration
        let offset = globalUsers.count

        SearchService.shared.searchUsers(
            query: trimmed,
            sort: 4,
            onlyOnline: false,
            offset: offset,
            count: globalPageSize
        ) { [weak self] users, total in
            DispatchQueue.main.async {
                guard let self, generation == self.searchGeneration else { return }
                let knownUIDs = Set(self.globalUsers.compactMap(\.uid))
                self.globalUsers.append(contentsOf: users.filter {
                    guard let uid = $0.uid else { return true }
                    return !knownUIDs.contains(uid)
                })
                self.globalHasMore = self.globalUsers.count < total && !users.isEmpty
                self.isLoadingGlobal = false
            }
        }
    }

    func createConversation(
        title: String,
        memberIDs: [Int],
        avatarData: Data?,
        completion: @escaping (Result<Conversation, Error>) -> Void
    ) {
        APIClient.shared.call(
            method: "messages.createChat",
            parameters: ["title": title, "user_ids": memberIDs.map(String.init).joined(separator: ",")],
            httpMethod: "POST",
            as: Int.self
        ) { [weak self] result in
            switch result {
            case .success(let chatID):
                let conversation = self?.newConversation(chatID: chatID, title: title, memberCount: memberIDs.count + 1)
                guard let conversation else { return }
                guard let avatarData else {
                    completion(.success(conversation))
                    return
                }
                self?.uploadChatAvatar(avatarData, chatID: chatID) { uploadResult in
                    switch uploadResult {
                    case .success:
                        completion(.success(conversation))
                    case .failure:
                        completion(.success(conversation))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func newConversation(chatID: Int, title: String, memberCount: Int) -> Conversation {
        Conversation(
            id: 2_000_000_000 + chatID,
            peer: User(
                uid: 2_000_000_000 + chatID,
                username: "chat\(chatID)",
                displayName: title,
                isGroup: true
            ),
            lastMessage: "",
            lastMessageAuthorName: nil,
            lastMessageOutgoing: false,
            updatedAt: Date(),
            unreadCount: 0,
            lastMessageId: 0,
            lastMessageReadState: nil,
            isChat: true,
            chatMemberCount: memberCount
        )
    }

    private func uploadChatAvatar(_ data: Data, chatID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        APIClient.shared.call(
            method: "photos.getChatUploadServer",
            parameters: ["chat_id": String(chatID)],
            httpMethod: "GET",
            as: ChatUploadServer.self
        ) { result in
            switch result {
            case .success(let server):
                APIClient.shared.upload(
                    urlString: server.uploadUrl,
                    fileData: data,
                    fileName: "chat_avatar.jpg",
                    mimeType: "image/jpeg"
                ) { uploadResult in
                    switch uploadResult {
                    case .success(let responseData):
                        do {
                            let uploaded = try JSONDecoder().decode(ChatAvatarUpload.self, from: responseData)
                            APIClient.shared.call(
                                method: "messages.setChatPhoto",
                                parameters: [
                                    "chat_id": String(chatID),
                                    "file": uploaded.photo,
                                    "hash": uploaded.hash
                                ],
                                httpMethod: "POST",
                                as: ChatPhotoUpdate.self
                            ) { result in
                                completion(result.map { _ in () }.mapError { $0 as Error })
                            }
                        } catch {
                            completion(.failure(error))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func loadFriendsPage() {
        let ownerID = AuthService.shared.currentUser?.uid ?? 0
        let parameters: [String: String] = [
            "user_id": String(ownerID),
            "fields": "photo_100,photo_200,online,last_seen,verified,screen_name,deactivated",
            "offset": String(friendsOffset),
            "count": String(friendsPageSize)
        ]

        APIClient.shared.call(
            method: "friends.get",
            parameters: parameters,
            httpMethod: "GET",
            as: VKSearchGenericResponse<VKUserProfile>.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success(let response):
                    let page = (response.items ?? []).map(self.makeUser)
                    self.friends.append(contentsOf: page)
                    self.friendsTotal = response.count ?? self.friends.count
                    self.friendsOffset += page.count

                    if !page.isEmpty && self.friendsOffset < self.friendsTotal {
                        self.loadFriendsPage()
                    } else {
                        self.friends.sort {
                            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                        }
                        self.isLoadingFriends = false
                    }
                case .failure(let error):
                    self.isLoadingFriends = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func makeUser(_ profile: VKUserProfile) -> User {
        let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return User(
            uid: profile.id,
            username: profile.screenName ?? "id\(profile.id)",
            displayName: profile.deactivated == "deleted" ? "Удалённый аккаунт" : (name.isEmpty ? "Пользователь" : name),
            avatarURL: (profile.photo200 ?? profile.photo100).flatMap(URL.init),
            isOnline: profile.online == 1,
            onlinePlatform: profile.lastSeen?.platformName,
            isOfficial: profile.verified == 1,
            deactivated: profile.deactivated
        )
    }
}

private struct ChatUploadServer: Decodable {
    let uploadUrl: String
}

private struct ChatAvatarUpload: Decodable {
    let photo: String
    let hash: String
}

private struct ChatPhotoUpdate: Decodable {}
