import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var isSending = false
    @Published var errorMessage: String?
    @Published var typingText: String?

    let conversation: Conversation
    private let service: MessagesService
    private let pageSize = 40
    private var offset = 0
    private var totalCount = 0
    private var hasMore = true
    private var observer: NSObjectProtocol?

    init(conversation: Conversation, service: MessagesService = .shared) {
        self.conversation = conversation
        self.service = service
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        service.fetchHistory(peerID: conversation.id, offset: 0, count: pageSize) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let page):
                self.messages = page.messages
                self.offset = page.messages.count
                self.totalCount = page.count
                self.hasMore = self.offset < self.totalCount && !page.messages.isEmpty
                self.service.markAsRead(peerID: self.conversation.id)
            case .failure(let error): self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    func loadOlderIfNeeded(message: ChatMessage) {
        guard message.id == messages.first?.id, hasMore, !isLoadingOlder else { return }
        isLoadingOlder = true
        service.fetchHistory(peerID: conversation.id, offset: offset, count: pageSize) { [weak self] result in
            guard let self else { return }
            if case .success(let page) = result {
                let existing = Set(self.messages.map(\.id))
                self.messages.insert(contentsOf: page.messages.filter { !existing.contains($0.id) }, at: 0)
                self.offset = self.messages.count
                self.totalCount = page.count
                self.hasMore = self.offset < self.totalCount && !page.messages.isEmpty
            }
            self.isLoadingOlder = false
        }
    }

    func send() {
        send(text: pendingText)
    }

    var pendingText = ""

    func send(text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !isSending else { return }
        isSending = true
        service.sendMessage(peerID: conversation.id, text: value) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success: self.load()
            case .failure(let error): self.errorMessage = error.localizedDescription
            }
            self.isSending = false
        }
    }

    func startListening() {
        observer = NotificationCenter.default.addObserver(forName: .openvkLongPollDidReceiveEvent, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self, let type = note.userInfo?["type"] as? Int else { return }
                if type == 4 || type == 5 || type == 14 || type == 51 || type == 52 {
                    if let peerID = note.userInfo?["peerID"] as? Int, peerID != self.conversation.id { return }
                    self.load()
                } else if (61...64).contains(type) {
                    self.updateTyping(note)
                }
            }
        }
    }

    private func updateTyping(_ note: Notification) {
        guard let peerID = note.userInfo?["peerID"] as? Int, peerID == conversation.id else { return }
        let ids = (note.userInfo?["userIDs"] as? [Int]) ?? ((note.userInfo?["userID"] as? Int).map { [$0] } ?? [])
        guard !ids.isEmpty else { return }
        if ids.count == 1 { typingText = "Печатает" }
        else { typingText = "Печатают (ids.count) человека" }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            self?.typingText = nil
        }
    }
}
