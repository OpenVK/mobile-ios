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
    private(set) var hasMore = true

    private let service: MessagesServiceProtocol
    private let pageSize = 20
    private var currentOffset = 0

    init(service: MessagesServiceProtocol = MessagesService.shared) {
        self.service = service
    }

    func load() {
        isLoading = true
        currentOffset = 0
        hasMore = true

        service.fetchConversations(offset: 0, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                if case .success(let items) = result {
                    self?.conversations = items
                    self?.currentOffset = items.count
                    self?.hasMore = items.count >= (self?.pageSize ?? 20)
                }
            }
        }
    }

    func loadMore() {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        service.fetchConversations(offset: currentOffset, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMore = false
                if case .success(let items) = result {
                    self?.conversations.append(contentsOf: items)
                    self?.currentOffset += items.count
                    self?.hasMore = items.count >= (self?.pageSize ?? 20)
                }
            }
        }
    }
}

final class ChatViewModel: ObservableObject {

    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var draft = ""
    @Published var shouldScrollToBottom = false
    @Published var scrollToMessageId: Int?
    @Published var selectedMessageIds: Set<Int> = []
    @Published var editingMessageId: Int?
    @Published var editingText = ""
    private(set) var hasMore = true

    var isSelecting: Bool { !selectedMessageIds.isEmpty }

    let peerID: Int
    let peerName: String

    private let service: MessagesServiceProtocol
    private let pageSize = 20
    private var currentOffset = 0

    init(peerID: Int, peerName: String, service: MessagesServiceProtocol = MessagesService.shared) {
        self.peerID = peerID
        self.peerName = peerName
        self.service = service
    }

    func load() {
        isLoading = true
        currentOffset = 0
        hasMore = true

        service.fetchMessages(peerID: peerID, offset: 0, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                if case .success(let msgs) = result {
                    self?.messages = msgs
                    self?.currentOffset = msgs.count
                    self?.hasMore = msgs.count >= (self?.pageSize ?? 20)
                }
            }
        }
    }

    func loadMore() {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        service.fetchMessages(peerID: peerID, offset: currentOffset, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMore = false
                if case .success(let msgs) = result {
                    self?.messages.append(contentsOf: msgs)
                    self?.currentOffset += msgs.count
                    self?.hasMore = msgs.count >= (self?.pageSize ?? 20)
                }
            }
        }
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draft = ""

        let tempMsg = Message(
            id: Int(Date().timeIntervalSince1970 * -1000),
            peerId: peerID,
            fromId: AuthService.shared.currentUser?.uid ?? 0,
            text: text,
            date: Date(),
            direction: .outgoing
        )
        messages.insert(tempMsg, at: 0)

        service.send(text: text, to: peerID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let messageId):
                    if let idx = self?.messages.firstIndex(where: { $0.id == tempMsg.id }) {
                        self?.messages[idx] = Message(
                            id: messageId,
                            peerId: self?.messages[idx].peerId ?? 0,
                            fromId: self?.messages[idx].fromId ?? 0,
                            text: text,
                            date: Date(),
                            direction: .outgoing
                        )
                    }
                case .failure:
                    self?.messages.removeAll { $0.id == tempMsg.id }
                }
            }
        }
    }

    func deleteMessage(_ id: Int) {
        service.delete(messageIDs: [id]) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.messages.removeAll { $0.id == id }
                    self?.selectedMessageIds.remove(id)
                }
            }
        }
    }

    func toggleSelection(_ id: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if selectedMessageIds.contains(id) {
                selectedMessageIds.remove(id)
            } else {
                selectedMessageIds.insert(id)
            }
        }
    }

    func clearSelection() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedMessageIds.removeAll()
        }
    }

    func deleteSelected() {
        let ids = Array(selectedMessageIds)
        service.delete(messageIDs: ids) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.messages.removeAll { self?.selectedMessageIds.contains($0.id) ?? false }
                    self?.clearSelection()
                }
            }
        }
    }

    func startEditing(_ message: Message) {
        editingMessageId = message.id
        editingText = message.text
        draft = message.text
    }

    func cancelEditing() {
        editingMessageId = nil
        editingText = ""
        draft = ""
    }

    func saveEdit() {
        guard let msgId = editingMessageId else { return }
        let newText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty else { return }

        service.edit(messageID: msgId, newText: newText) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    if let idx = self?.messages.firstIndex(where: { $0.id == msgId }) {
                        self?.messages[idx] = Message(
                            id: msgId,
                            peerId: self?.messages[idx].peerId ?? 0,
                            fromId: self?.messages[idx].fromId ?? 0,
                            text: newText,
                            date: self?.messages[idx].date ?? Date(),
                            direction: .outgoing
                        )
                    }
                }
                self?.cancelEditing()
            }
        }
    }
}
