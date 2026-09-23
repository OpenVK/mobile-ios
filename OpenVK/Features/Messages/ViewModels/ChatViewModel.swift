import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingOlder = false
    @Published var errorMessage: String?
    @Published var typingText: String?
    @Published private(set) var stickerPacks: [VKStickerPack] = []
    @Published private(set) var isLoadingStickerPacks = false
    @Published private(set) var isPeerOnline: Bool
    @Published private(set) var peerLastSeen: Date?
    @Published private(set) var canSendMessages: Bool

    let conversation: Conversation
    private let service: MessagesService
    private let pageSize = 40
    private var offset = 0
    private var totalCount = 0
    private var hasMore = true
    private var observer: NSObjectProtocol?
    private var lastTypingSentAt = Date.distantPast
    private var typingExpirations: [Int: Date] = [:]
    private var typingNames: [Int: String] = [:]

    init(conversation: Conversation, service: MessagesService = .shared) {
        self.conversation = conversation
        self.service = service
        isPeerOnline = conversation.peer.isOnline
        peerLastSeen = nil
        canSendMessages = !conversation.isChat || conversation.isChatMember
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
                self.messages = self.mergingTransientMessages(into: page.messages)
                if page.messages.contains(where: { $0.endsChatParticipation }) {
                    self.canSendMessages = false
                }
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

    func send(text: String) {
        guard canSendMessages else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let pendingMessage = ChatMessage.pending(text: value)
        messages.append(pendingMessage)

        service.sendMessage(peerID: conversation.id, text: value) { [weak self] result in
            guard let self else { return }
            guard let index = self.messages.firstIndex(where: { $0.id == pendingMessage.id }) else { return }
            switch result {
            case .success(let id):
                if self.messages.contains(where: { $0.id == id }) {
                    self.messages.remove(at: index)
                    // A Long Poll refresh may already have supplied the server copy.
                } else {
                    self.messages[index] = pendingMessage.updatingDeliveryStatus(.unread, id: id)
                }
            case .failure:
                self.messages[index] = pendingMessage.updatingDeliveryStatus(.failed)
            }
        }
    }

    func loadStickerPacks() {
        guard stickerPacks.isEmpty, !isLoadingStickerPacks else { return }
        isLoadingStickerPacks = true
        service.fetchStickerPacks { [weak self] result in
            guard let self else { return }
            if case .success(let packs) = result { self.stickerPacks = packs }
            self.isLoadingStickerPacks = false
        }
    }

    func send(sticker: VKSticker) {
        guard canSendMessages else { return }
        guard let stickerID = sticker.identifier else { return }
        let pendingMessage = ChatMessage.pending(sticker: sticker)
        messages.append(pendingMessage)

        service.sendSticker(peerID: conversation.id, stickerID: stickerID) { [weak self] result in
            guard let self, let index = self.messages.firstIndex(where: { $0.id == pendingMessage.id }) else { return }
            switch result {
            case .success(let id): self.messages[index] = pendingMessage.updatingDeliveryStatus(.unread, id: id)
            case .failure: self.messages[index] = pendingMessage.updatingDeliveryStatus(.failed)
            }
        }
    }

    func sendTyping(for text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard Date().timeIntervalSince(lastTypingSentAt) >= 3 else { return }
        lastTypingSentAt = Date()
        service.setTyping(peerID: conversation.id)
    }

    var peerPresenceText: String? {
        guard !conversation.isChat, !conversation.isGroup else { return nil }
        if isPeerOnline {
            if let platform = conversation.peer.onlinePlatform, !platform.isEmpty {
                return "В сети · \(platform)"
            }
            return "В сети"
        }
        if let peerLastSeen {
            return peerLastSeen.openvkLastSeen(sex: conversation.peer.sex)
        }
        return conversation.peer.lastSeen ?? "Не в сети"
    }

    func startListening() {
        observer = NotificationCenter.default.addObserver(forName: .openvkLongPollDidReceiveEvent, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self, let type = note.userInfo?["type"] as? Int else { return }
                if type == 3 {
                    self.handleReadFlagEvent(note)
                } else if type == 7 {
                    if let peerID = note.userInfo?["peerID"] as? Int, peerID == self.conversation.id {
                        self.load()
                    }
                } else if type == 8 || type == 9 {
                    self.updatePeerPresence(note, isOnline: type == 8)
                } else if type == 4 || type == 5 || type == 14 || type == 51 || type == 52 {
                    if let peerID = note.userInfo?["peerID"] as? Int, peerID != self.conversation.id { return }
                    self.load()
                } else if (61...64).contains(type) {
                    self.updateTyping(note)
                }
            }
        }
    }

    private func updateTyping(_ note: Notification) {
        let ids = (note.userInfo?["userIDs"] as? [Int]) ?? ((note.userInfo?["userID"] as? Int).map { [$0] } ?? [])
        guard !ids.isEmpty else { return }
        if let peerID = note.userInfo?["peerID"] as? Int {
            guard peerID == conversation.id else { return }
        } else {
            guard !conversation.isChat, ids.contains(abs(conversation.peer.uid ?? 0)) else { return }
        }
        let currentUserID = AuthService.shared.currentUser?.uid
        let activeIDs = ids.filter { $0 != currentUserID }
        guard !activeIDs.isEmpty else { return }
        let expiration = Date().addingTimeInterval(4)
        for id in activeIDs { typingExpirations[id] = expiration }
        updateTypingText()
        resolveTypingNames(for: activeIDs)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self else { return }
            let now = Date()
            let expiredIDs = self.typingExpirations.filter { $0.value <= now }.map(\.key)
            self.typingExpirations = self.typingExpirations.filter { $0.value > now }
            for id in expiredIDs { self.typingNames.removeValue(forKey: id) }
            self.updateTypingText()
        }
    }

    private func updateTypingText() {
        let ids = Array(typingExpirations.keys).sorted()
        let count = ids.count
        guard count > 0 else {
            typingText = nil
            return
        }
        if count == 1 {
            typingText = "\(typingNames[ids[0]] ?? "Пользователь") печатает"
        } else if count == 2 {
            let first = typingNames[ids[0]] ?? "Пользователь"
            let second = typingNames[ids[1]] ?? "Пользователь"
            typingText = "\(first) и \(second) печатают"
        } else {
            let lastTwo = count % 100
            let last = count % 10
            let noun = (11...14).contains(lastTwo) ? "человек" : ((2...4).contains(last) ? "человека" : "человек")
            typingText = "Печатают \(count) \(noun)"
        }
    }

    private func resolveTypingNames(for userIDs: [Int]) {
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
            guard let self, case .success(let profiles) = result else { return }
            for profile in profiles {
                let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self.typingNames[profile.id] = name.isEmpty
                    ? (profile.screenName ?? "Пользователь \(profile.id)")
                    : name
            }
            self.updateTypingText()
        }
    }

    private func handleReadFlagEvent(_ note: Notification) {
        guard let peerID = note.userInfo?["peerID"] as? Int, peerID == conversation.id,
              let messageID = note.userInfo?["messageID"] as? Int,
              let event = note.userInfo?["event"] as? [Any], event.count > 2,
              let flags = event[2] as? Int, flags & 1 == 1,
              let index = messages.firstIndex(where: { $0.id == messageID && $0.isOutgoing }) else { return }
        messages[index] = messages[index].updatingDeliveryStatus(.read)
    }

    private func updatePeerPresence(_ note: Notification, isOnline: Bool) {
        guard !conversation.isChat, !conversation.isGroup,
              let userID = note.userInfo?["userID"] as? Int,
              userID == abs(conversation.peer.uid ?? 0) else { return }
        isPeerOnline = isOnline
        if !isOnline, let event = note.userInfo?["event"] as? [Any] {
            let timestamp = (event.count > 4 ? event[4] : nil) as? Int ?? (event.count > 3 ? event[3] : nil) as? Int
            peerLastSeen = Date(timeIntervalSince1970: TimeInterval(timestamp ?? Int(Date().timeIntervalSince1970)))
        }
    }

    private func mergingTransientMessages(into loadedMessages: [ChatMessage]) -> [ChatMessage] {
        let transientMessages = messages.filter {
            $0.deliveryStatus == .sending || $0.deliveryStatus == .failed
        }
        return (loadedMessages + transientMessages)
            .sorted { $0.date < $1.date }
    }
}
