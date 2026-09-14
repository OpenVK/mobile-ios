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
    @Published var errorMessage: String?

    private let service: MessagesServiceProtocol
    private let pageSize = 30
    private var currentOffset = 0
    private var totalCount = 0
    private var hasMore = true

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
