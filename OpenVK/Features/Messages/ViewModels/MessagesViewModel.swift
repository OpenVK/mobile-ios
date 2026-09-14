//
//  MessagesViewModel.swift
//  OpenVK for iOS
//

import Foundation
import SwiftUI

final class MessagesViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var typingUsersByConversation: [Int: [String]] = [:]
    @Published var errorMessage: String?

    private let service: MessagesServiceProtocol
    private let pageSize = 30
    private var currentOffset = 0
    private var totalCount = 0
    private var hasMore = true
    private var typingExpirations: [Int: [Int: Date]] = [:]
    private var typingNames: [Int: [Int: String]] = [:]

    init(service: MessagesServiceProtocol = MessagesService.shared) {
        self.service = service
    }

    func load() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        currentOffset = 0
        totalCount = 0
        hasMore = true

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
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func loadMoreIfNeeded(after conversation: Conversation) {
        guard conversation.id == conversations.last?.id else { return }
        loadMore()
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
        return "\(names.count) человек печатает"
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
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
