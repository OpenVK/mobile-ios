//
//  MessagesViewModel.swift
//  OpenVK for iOS
//

import Foundation
import SwiftUI

// The server currently has no conversation archive endpoint. Keep archive
// membership locally per OpenVK host and authenticated user.
enum ChatArchiveStore {
    static let didChange = Notification.Name("openvkChatArchiveDidChange")

    private static var key: String {
        "openvk.archive.\(AppConfig.currentHost).\(AuthService.shared.currentUser?.uid ?? 0)"
    }

    private static var firstArchiveTipKey: String {
        "openvk.archive.tip.shown.\(AppConfig.currentHost).\(AuthService.shared.currentUser?.uid ?? 0)"
    }

    private static var pendingArchiveTipKey: String {
        "openvk.archive.tip.pending.\(AppConfig.currentHost).\(AuthService.shared.currentUser?.uid ?? 0)"
    }

    static func takePendingFirstArchiveTip() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingArchiveTipKey) else { return false }
        UserDefaults.standard.set(false, forKey: pendingArchiveTipKey)
        UserDefaults.standard.set(true, forKey: firstArchiveTipKey)
        return true
    }

    static func archivedPeerIDs() -> [Int] {
        UserDefaults.standard.array(forKey: key)?.compactMap { $0 as? Int } ?? []
    }

    static func contains(_ peerID: Int) -> Bool {
        archivedPeerIDs().contains(peerID)
    }

    static func setArchived(_ archived: Bool, peerID: Int) {
        var ids = Set(archivedPeerIDs())
        if archived {
            if !ids.contains(peerID) && !UserDefaults.standard.bool(forKey: firstArchiveTipKey) {
                UserDefaults.standard.set(true, forKey: pendingArchiveTipKey)
            }
            ids.insert(peerID)
        } else {
            ids.remove(peerID)
        }
        UserDefaults.standard.set(Array(ids), forKey: key)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

final class MessagesViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation] = [] {
        didSet { persistConversations() }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var typingUsersByConversation: [Int: [String]] = [:]
    @Published private(set) var searchResults: [Conversation] = []
    @Published private(set) var isSearching = false
    @Published var searchQuery = ""
    @Published private(set) var archiveRevision = 0
    @Published private(set) var fetchedArchivedConversations: [Conversation] = []
    @Published private(set) var isLoadingArchive = false
    @Published var errorMessage: String?

    private let service: MessagesServiceProtocol
    private let pageSize = 30
    private var currentOffset = 0
    private var totalCount = 0
    private var hasMore = true
    private var typingExpirations: [Int: [Int: Date]] = [:]
    private var typingNames: [Int: [Int: String]] = [:]
    private var searchWorkItem: DispatchWorkItem?
    private var archiveRequestID = 0

    var displayedConversations: [Conversation] {
        let all = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? conversations
            : searchResults
        return all.filter { !ChatArchiveStore.contains($0.id) }
    }

    var archivedConversations: [Conversation] {
        let loaded = conversations.filter { ChatArchiveStore.contains($0.id) }
        let loadedIDs = Set(loaded.map(\.id))
        let older = fetchedArchivedConversations.filter {
            ChatArchiveStore.contains($0.id) && !loadedIDs.contains($0.id)
        }
        return (loaded + older).sorted { $0.updatedAt > $1.updatedAt }
    }

    var hasArchivedConversations: Bool {
        !ChatArchiveStore.archivedPeerIDs().isEmpty
    }

    func archive(_ conversation: Conversation, archived: Bool) {
        ChatArchiveStore.setArchived(archived, peerID: conversation.id)
    }

    func refreshArchive() {
        archiveRevision &+= 1
        refreshArchivedConversations()
    }

    private func refreshArchivedConversations() {
        archiveRequestID &+= 1
        let requestID = archiveRequestID
        let ids = ChatArchiveStore.archivedPeerIDs()
        guard !ids.isEmpty else {
            isLoadingArchive = false
            fetchedArchivedConversations = []
            return
        }
        isLoadingArchive = true
        service.fetchConversationsByIDs(ids) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.archiveRequestID == requestID else { return }
                self.isLoadingArchive = false
                switch result {
                case .success(let page):
                    self.fetchedArchivedConversations = page.conversations.filter {
                        ChatArchiveStore.contains($0.id)
                    }
                case .failure(let error):
                    if !MessagesService.isConnectionFailure(error) {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    init(service: MessagesServiceProtocol = MessagesService.shared) {
        self.service = service
        if let saved = service.cachedConversations() {
            conversations = saved.conversations
            totalCount = saved.totalCount
            currentOffset = conversations.count
            hasMore = currentOffset < totalCount
        }
    }

    private func persistConversations(removing peerID: Int? = nil) {
        var saved = Dictionary((service.cachedConversations()?.conversations ?? []).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for conversation in conversations { saved[conversation.id] = conversation }
        if let peerID { saved.removeValue(forKey: peerID) }
        let items = saved.values.sorted { $0.updatedAt > $1.updatedAt }
        service.cacheConversations(ConversationsPage(totalCount: max(totalCount, items.count), conversations: items))
    }

    func load() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        service.fetchConversations(offset: 0, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success(let page):
                    self.conversations = page.conversations
                    self.totalCount = page.totalCount
                    self.currentOffset = page.conversations.count
                    self.hasMore = self.currentOffset < self.totalCount &&
                        !page.conversations.isEmpty
                    self.refreshArchivedConversations()
                case .failure(let error):
                    if !MessagesService.isConnectionFailure(error) {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func loadMoreIfNeeded(after conversation: Conversation) {
        guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard conversation.id == conversations.last?.id else { return }
        loadMore()
    }

    func updateSearch(query: String) {
        searchQuery = query
        searchWorkItem?.cancel()

        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == value else { return }
            self.service.searchConversations(query: value) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self,
                          self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == value else { return }
                    self.isSearching = false
                    switch result {
                    case .success(let page):
                        self.searchResults = page.conversations.map { result in
                            self.conversations.first(where: { $0.id == result.id }) ?? result
                        }
                    case .failure(let error):
                        self.searchResults = []
                        if !MessagesService.isConnectionFailure(error) {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    func handleLongPollEvent(_ notification: Notification) {
        guard let type = notification.userInfo?["type"] as? Int,
              (61...64).contains(type) else {
            return
        }

        let userIDs: [Int]
        if let ids = notification.userInfo?["userIDs"] as? [Int] {
            userIDs = ids
        } else if let userID = notification.userInfo?["userID"] as? Int {
            userIDs = [userID]
        } else {
            return
        }
        let peerID = notification.userInfo?["peerID"] as? Int
        guard let conversation = conversations.first(where: {
            if let peerID { return $0.id == peerID }
            return !$0.isChat && $0.peer.uid == userIDs.first
        }) else { return }

        let expiration = Date().addingTimeInterval(4)
        var users = typingExpirations[conversation.id] ?? [:]
        for userID in userIDs { users[userID] = expiration }
        typingExpirations[conversation.id] = users
        typingUsersByConversation[conversation.id] = displayNames(for: users.keys, conversation: conversation)

        if conversation.isChat {
            resolveTypingNames(userIDs: userIDs, conversation: conversation)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            for userID in userIDs {
                guard self.typingExpirations[conversation.id]?[userID] == expiration else { continue }
                self.typingExpirations[conversation.id]?.removeValue(forKey: userID)
            }
            if self.typingExpirations[conversation.id]?.isEmpty == true {
                self.typingExpirations.removeValue(forKey: conversation.id)
                self.typingNames.removeValue(forKey: conversation.id)
                self.typingUsersByConversation.removeValue(forKey: conversation.id)
            }
        }
    }

    private func displayNames<S: Sequence>(for userIDs: S, conversation: Conversation) -> [String] where S.Element == Int {
        userIDs.map { userID in
            if let name = typingNames[conversation.id]?[userID] { return name }
            if !conversation.isChat, userID == conversation.peer.uid {
                return firstNameOnly(conversation.peer.displayName)
            }
            return "Пользователь \(userID)"
        }
    }

    private func resolveTypingNames(userIDs: [Int], conversation: Conversation) {
        let ids = Array(Set(userIDs)).filter { $0 > 0 }
        guard !ids.isEmpty else { return }
        APIClient.shared.call(
            method: "users.get",
            parameters: [
                "user_ids": ids.map(String.init).joined(separator: ","),
                "fields": "first_name,last_name,screen_name"
            ],
            httpMethod: "GET",
            as: [VKUserProfile].self
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard case .success(let profiles) = result else { return }
                var names = self.typingNames[conversation.id] ?? [:]
                for profile in profiles {
                    let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    names[profile.id] = name.isEmpty
                        ? self.firstNameOnly(profile.screenName ?? "Пользователь \(profile.id)")
                        : self.firstNameOnly(name)
                }
                self.typingNames[conversation.id] = names
                if let activeUsers = self.typingExpirations[conversation.id]?.keys {
                    self.typingUsersByConversation[conversation.id] = self.displayNames(for: activeUsers, conversation: conversation)
                }
            }
        }
    }

    private func firstNameOnly(_ name: String) -> String {
        name.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? name
    }

    func typingText(for conversation: Conversation) -> String? {
        guard let names = typingUsersByConversation[conversation.id], !names.isEmpty else { return nil }
        if names.count == 1 { return "\(names[0]) печатает" }
        if names.count == 2 { return "\(names[0]) и \(names[1]) печатают" }
        let count = names.count
        let lastTwoDigits = count % 100
        let lastDigit = count % 10
        let noun = (11...14).contains(lastTwoDigits)
            ? "человек"
            : (2...4).contains(lastDigit) ? "человека" : "человек"
        return "\(count) \(noun) печатают"
    }

    func markConversationAsRead(_ conversation: Conversation) {
        service.markConversationAsRead(peerID: conversation.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.conversations = self.conversations.map { item in
                        guard item.id == conversation.id else { return item }
                        return Conversation(
                            id: item.id,
                            peer: item.peer,
                            lastMessage: item.lastMessage,
                            lastMessageAuthorName: item.lastMessageAuthorName,
                            lastMessageOutgoing: item.lastMessageOutgoing,
                            updatedAt: item.updatedAt,
                            unreadCount: 0,
                            lastMessageId: item.lastMessageId,
                            lastMessageReadState: item.lastMessageReadState,
                            isChat: item.isChat,
                            isChatMember: item.isChatMember,
                            chatMemberCount: item.chatMemberCount,
                            inReadMessageID: item.inReadMessageID,
                            outReadMessageID: item.outReadMessageID,
                            inReadConversationMessageID: item.inReadConversationMessageID,
                            outReadConversationMessageID: item.outReadConversationMessageID,
                            lastConversationMessageID: item.lastConversationMessageID,
                            isImportant: item.isImportant,
                            isUnanswered: item.isUnanswered
                        )
                    }
                    self.searchResults = self.searchResults.map { item in
                        guard item.id == conversation.id else { return item }
                        var copy = item
                        copy = Conversation(
                            id: copy.id,
                            peer: copy.peer,
                            lastMessage: copy.lastMessage,
                            lastMessageAuthorName: copy.lastMessageAuthorName,
                            lastMessageOutgoing: copy.lastMessageOutgoing,
                            updatedAt: copy.updatedAt,
                            unreadCount: 0,
                            lastMessageId: copy.lastMessageId,
                            lastMessageReadState: copy.lastMessageReadState,
                            isChat: copy.isChat,
                            isChatMember: copy.isChatMember,
                            chatMemberCount: copy.chatMemberCount,
                            inReadMessageID: copy.inReadMessageID,
                            outReadMessageID: copy.outReadMessageID,
                            inReadConversationMessageID: copy.inReadConversationMessageID,
                            outReadConversationMessageID: copy.outReadConversationMessageID,
                            lastConversationMessageID: copy.lastConversationMessageID,
                            isImportant: copy.isImportant,
                            isUnanswered: copy.isUnanswered
                        )
                        return copy
                    }
                    AuthService.shared.fetchCounters()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func toggleImportant(_ conversation: Conversation) {
        let newValue = !conversation.isImportant
        service.markConversationImportant(peerID: conversation.id, important: newValue) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.updateConversationImportance(id: conversation.id, important: newValue)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func updateConversationImportance(id: Int, important: Bool) {
        func updated(_ items: [Conversation]) -> [Conversation] {
            items.map { item in
                guard item.id == id else { return item }
                var copy = item
                copy.isImportant = important
                return copy
            }
        }
        conversations = updated(conversations)
        searchResults = updated(searchResults)
    }

    func updateUnreadCount(_ notification: Notification) {
        guard let peerID = notification.userInfo?["peerID"] as? Int,
              let unreadCount = notification.userInfo?["unreadCount"] as? Int else { return }
        let value = max(0, unreadCount)
        if let index = conversations.firstIndex(where: { $0.id == peerID }) {
            conversations[index].unreadCount = value
        }
        if let index = searchResults.firstIndex(where: { $0.id == peerID }) {
            searchResults[index].unreadCount = value
        }
        if let index = fetchedArchivedConversations.firstIndex(where: { $0.id == peerID }) {
            fetchedArchivedConversations[index].unreadCount = value
        }
    }

    func deleteConversation(_ conversation: Conversation) {
        service.deleteConversation(peerID: conversation.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.conversations.removeAll { $0.id == conversation.id }
                    self.totalCount = max(0, self.totalCount - 1)
                    AuthService.shared.fetchCounters()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func leaveChat(_ conversation: Conversation, deleteChat: Bool) {
        service.leaveChat(peerID: conversation.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    if deleteChat {
                        self.service.deleteConversation(peerID: conversation.id) { [weak self] deleteResult in
                            DispatchQueue.main.async {
                                guard let self else { return }
                                self.removeConversationLocally(conversation)
                                if case .failure(let error) = deleteResult {
                                    self.errorMessage = error.localizedDescription
                                }
                                AuthService.shared.fetchCounters()
                            }
                        }
                    } else {
                        self.removeConversationLocally(conversation)
                        AuthService.shared.fetchCounters()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func removeConversationLocally(_ conversation: Conversation) {
        let oldCount = conversations.count
        conversations.removeAll { $0.id == conversation.id }
        searchResults.removeAll { $0.id == conversation.id }
        if conversations.count != oldCount {
            totalCount = max(0, totalCount - 1)
        }
        persistConversations(removing: conversation.id)
    }

    private func loadMore() {
        guard !isLoading, !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        service.fetchConversations(offset: currentOffset, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingMore = false

                switch result {
                case .success(let page):
                    let knownIDs = Set(self.conversations.map(\.id))
                    self.conversations.append(contentsOf: page.conversations.filter {
                        !knownIDs.contains($0.id)
                    })
                    self.totalCount = page.totalCount
                    self.currentOffset = self.conversations.count
                    self.hasMore = self.currentOffset < self.totalCount &&
                        !page.conversations.isEmpty
                case .failure(let error):
                    if !MessagesService.isConnectionFailure(error) {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
