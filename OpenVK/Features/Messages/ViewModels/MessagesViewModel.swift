//
//  MessagesViewModel.swift
//  OpenVK for iOS
//

import Foundation
import SwiftUI
import Combine

final class MessagesViewModel: ObservableObject {

    @Published var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var searchQuery = "" {
        didSet {
            searchDebounceSubject.send(searchQuery)
        }
    }
    @Published private(set) var typingPeers: [Int: String] = [:]

    var filteredConversations: [Conversation] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return conversations }
        return conversations.filter { convo in
            convo.peer.title.localizedCaseInsensitiveContains(q) ||
            convo.lastMessage.localizedCaseInsensitiveContains(q)
        }
    }

    private(set) var hasMore = true
    private let service: MessagesServiceProtocol
    private let longPoll: LongPollService
    private let pageSize = 20
    private var currentOffset = 0
    private var cancellables = Set<AnyCancellable>()
    private let searchDebounceSubject = PassthroughSubject<String, Never>()
    private var typingResetTimers: [Int: AnyCancellable] = [:]

    init(
        service: MessagesServiceProtocol = MessagesService.shared,
        longPoll: LongPollService = LongPollService.shared
    ) {
        self.service = service
        self.longPoll = longPoll

        setupLongPollSubscription()
        setupSearchDebounce()
    }

    private func setupLongPollSubscription() {
        longPoll.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleLongPollEvent(event)
            }
            .store(in: &cancellables)

        longPoll.start()
    }

    private func setupSearchDebounce() {
        searchDebounceSubject
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if q.isEmpty {
                    self.load()
                } else {
                    self.performSearch(query: q)
                }
            }
            .store(in: &cancellables)
    }

    func load() {
        isLoading = true
        currentOffset = 0
        hasMore = true

        service.fetchConversations(offset: 0, count: pageSize, filter: nil, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if case .success(let items) = result {
                    self.conversations = items
                    self.currentOffset = items.count
                    self.hasMore = items.count >= self.pageSize
                }
            }
        }
    }

    func loadMore() {
        guard !isLoadingMore, hasMore, searchQuery.isEmpty else { return }

        isLoadingMore = true
        service.fetchConversations(offset: currentOffset, count: pageSize, filter: nil, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingMore = false
                if case .success(let items) = result {
                    self.conversations.append(contentsOf: items)
                    self.currentOffset += items.count
                    self.hasMore = items.count >= self.pageSize
                }
            }
        }
    }

    private func performSearch(query: String) {
        isLoading = true
        service.searchConversations(query: query, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if case .success(let items) = result {
                    self.conversations = items
                    self.hasMore = false
                }
            }
        }
    }

    func createChat(title: String, userIds: [Int], completion: @escaping (Result<Int, Error>) -> Void) {
        service.createChat(title: title, userIds: userIds, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.load()
                }
                completion(result)
            }
        }
    }

    func toggleImportant(conversation: Conversation) {
        let newImportant = !conversation.isImportant
        service.markAsImportantConversation(peerID: conversation.peer.id, important: newImportant, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    if let idx = self?.conversations.firstIndex(where: { $0.peer.id == conversation.peer.id }) {
                        let c = self!.conversations[idx]
                        self?.conversations[idx] = Conversation(
                            id: c.id,
                            peer: c.peer,
                            lastMessage: c.lastMessage,
                            lastMessageOutgoing: c.lastMessageOutgoing,
                            updatedAt: c.updatedAt,
                            unreadCount: c.unreadCount,
                            lastMessageId: c.lastMessageId,
                            inRead: c.inRead,
                            outRead: c.outRead,
                            chatSettings: c.chatSettings,
                            isImportant: newImportant,
                            isAnswered: c.isAnswered,
                            isMuted: c.isMuted
                        )
                    }
                }
            }
        }
    }

    func markAsRead(conversation: Conversation) {
        service.markAsRead(peerID: conversation.peer.id, startMessageId: conversation.lastMessageId, messageIDs: nil, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    if let idx = self?.conversations.firstIndex(where: { $0.peer.id == conversation.peer.id }) {
                        let c = self!.conversations[idx]
                        self?.conversations[idx] = Conversation(
                            id: c.id,
                            peer: c.peer,
                            lastMessage: c.lastMessage,
                            lastMessageOutgoing: c.lastMessageOutgoing,
                            updatedAt: c.updatedAt,
                            unreadCount: 0,
                            lastMessageId: c.lastMessageId,
                            inRead: c.lastMessageId,
                            outRead: c.outRead,
                            chatSettings: c.chatSettings,
                            isImportant: c.isImportant,
                            isAnswered: c.isAnswered,
                            isMuted: c.isMuted
                        )
                    }
                }
            }
        }
    }

    private func handleLongPollEvent(_ event: LongPollEvent) {
        switch event {
        case .newMessage(let id, let flags, let peerId, let date, let text, _, _, _):
            let isOut = (flags & 2) != 0
            if let idx = conversations.firstIndex(where: { $0.peer.id == peerId }) {
                var c = conversations.remove(at: idx)
                let unread = isOut ? c.unreadCount : c.unreadCount + 1
                c = Conversation(
                    id: c.id,
                    peer: c.peer,
                    lastMessage: text.isEmpty ? "[Вложение]" : text,
                    lastMessageOutgoing: isOut,
                    updatedAt: date,
                    unreadCount: unread,
                    lastMessageId: id,
                    inRead: c.inRead,
                    outRead: c.outRead,
                    chatSettings: c.chatSettings,
                    isImportant: c.isImportant,
                    isAnswered: c.isAnswered,
                    isMuted: c.isMuted
                )
                conversations.insert(c, at: 0)
            } else {
                service.fetchConversationsById(peerIds: [peerId], groupId: nil) { [weak self] result in
                    DispatchQueue.main.async {
                        if case .success(let items) = result, let newConv = items.first {
                            self?.conversations.insert(newConv, at: 0)
                        }
                    }
                }
            }

        case .typing(let peerId, _):
            typingPeers[peerId] = "печатает..."
            typingResetTimers[peerId]?.cancel()
            typingResetTimers[peerId] = Just(())
                .delay(for: .seconds(5), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.typingPeers.removeValue(forKey: peerId)
                }

        case .chatUpdated:
            load()

        default:
            break
        }
    }
}

final class ChatViewModel: ObservableObject {

    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var draft = "" {
        didSet {
            typingDebounceSubject.send(())
        }
    }
    @Published var replyingToMessage: Message?
    @Published var editingMessageId: Int?
    @Published var pinnedMessage: Message?
    @Published var selectedMessageIds: Set<Int> = []
    @Published var isPeerTyping = false
    @Published var peerTypingText: String?
    @Published var shouldScrollToBottom = false
    @Published var scrollToMessageId: Int?
    @Published var highlightedMessageId: Int?
    @Published var messageReactions: [Int: String] = [:]
    @Published var attachedImages: [UIImage] = []

    private(set) var hasMore = true
    let peer: Peer
    var peerID: Int { peer.id }
    var peerName: String { peer.title }

    var isSelecting: Bool { !selectedMessageIds.isEmpty }

    private let service: MessagesServiceProtocol
    private let longPoll: LongPollService
    private let pageSize = 30
    private var currentOffset = 0
    private var cancellables = Set<AnyCancellable>()
    private let typingDebounceSubject = PassthroughSubject<Void, Never>()
    private var typingResetTimer: AnyCancellable?

    init(
        peer: Peer,
        service: MessagesServiceProtocol = MessagesService.shared,
        longPoll: LongPollService = LongPollService.shared
    ) {
        self.peer = peer
        self.service = service
        self.longPoll = longPoll

        setupLongPollSubscription()
        setupTypingBroadcaster()
    }

    convenience init(
        peerID: Int,
        peerName: String,
        service: MessagesServiceProtocol = MessagesService.shared
    ) {
        let pType: PeerType = peerID >= 2000000000 ? .chat : (peerID < 0 ? .group : .user)
        let p = Peer(id: peerID, type: pType, title: peerName)
        self.init(peer: p, service: service)
    }

    private func setupLongPollSubscription() {
        longPoll.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleLongPollEvent(event)
            }
            .store(in: &cancellables)
    }

    private func setupTypingBroadcaster() {
        typingDebounceSubject
            .throttle(for: .seconds(4), scheduler: DispatchQueue.main, latest: false)
            .sink { [weak self] in
                guard let self = self, !self.draft.isEmpty else { return }
                self.service.setActivity(peerID: self.peerID, type: "typing", groupId: nil) { _ in }
            }
            .store(in: &cancellables)
    }

    func load() {
        isLoading = true
        currentOffset = 0
        hasMore = true

        service.fetchMessages(peerID: peerID, offset: 0, count: pageSize, startMessageId: nil, rev: nil, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if case .success(let msgs) = result {
                    var uniqueMsgs: [Message] = []
                    var seenIds = Set<Int>()
                    for m in msgs {
                        if seenIds.insert(m.id).inserted {
                            uniqueMsgs.append(m)
                        }
                    }
                    self.messages = uniqueMsgs
                    self.currentOffset = msgs.count
                    self.hasMore = msgs.count >= self.pageSize
                    self.markLastAsRead()
                }
            }
        }
    }

    func loadMore() {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        service.fetchMessages(peerID: peerID, offset: currentOffset, count: pageSize, startMessageId: nil, rev: nil, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingMore = false
                if case .success(let msgs) = result {
                    var currentIds = Set(self.messages.map { $0.id })
                    for m in msgs {
                        if currentIds.insert(m.id).inserted {
                            self.messages.append(m)
                        }
                    }
                    self.currentOffset += msgs.count
                    self.hasMore = msgs.count >= self.pageSize
                }
            }
        }
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachedImages.isEmpty else { return }

        let replyId = replyingToMessage?.id
        draft = ""
        replyingToMessage = nil

        let tempId = Int(Date().timeIntervalSince1970 * -1000) - Int.random(in: 1...999)
        let tempMsg = Message(
            id: tempId,
            peerId: peerID,
            fromId: AuthService.shared.currentUser?.uid ?? 0,
            text: text,
            date: Date(),
            direction: .outgoing,
            isRead: false
        )
        messages.insert(tempMsg, at: 0)

        service.send(text: text, to: peerID, attachments: nil, replyTo: replyId, stickerId: nil, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let messageId):
                    if self.messages.contains(where: { $0.id == messageId }) {
                        self.messages.removeAll { $0.id == tempId }
                    } else if let idx = self.messages.firstIndex(where: { $0.id == tempId }) {
                        self.messages[idx] = Message(
                            id: messageId,
                            peerId: self.peerID,
                            fromId: self.messages[idx].fromId,
                            text: text,
                            date: Date(),
                            direction: .outgoing,
                            isRead: false
                        )
                    }
                case .failure:
                    self.messages.removeAll { $0.id == tempId }
                }
            }
        }
    }

    func sendSticker(_ sticker: Sticker) {
        service.send(text: "", to: peerID, attachments: nil, replyTo: replyingToMessage?.id, stickerId: sticker.id, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.replyingToMessage = nil
                if case .success(let messageId) = result {
                    if !self.messages.contains(where: { $0.id == messageId }) {
                        let stMsg = Message(
                            id: messageId,
                            peerId: self.peerID,
                            fromId: AuthService.shared.currentUser?.uid ?? 0,
                            text: "",
                            date: Date(),
                            direction: .outgoing,
                            isRead: false,
                            sticker: sticker
                        )
                        self.messages.insert(stMsg, at: 0)
                    }
                }
            }
        }
    }

    func startReply(to message: Message) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.cancelEditing()
            self.replyingToMessage = message
        }
    }

    func cancelReply() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.replyingToMessage = nil
        }
    }

    func startEditing(_ message: Message) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.cancelReply()
            self.editingMessageId = message.id
            self.draft = message.text
        }
    }

    func cancelEditing() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.editingMessageId = nil
            self.draft = ""
        }
    }

    func saveEdit() {
        guard let msgId = editingMessageId else { return }
        let newText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty else { return }

        service.edit(peerID: peerID, messageID: msgId, newText: newText, attachments: nil, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case .success = result {
                    if let idx = self.messages.firstIndex(where: { $0.id == msgId }) {
                        let old = self.messages[idx]
                        self.messages[idx] = Message(
                            id: old.id,
                            peerId: old.peerId,
                            fromId: old.fromId,
                            text: newText,
                            date: old.date,
                            direction: old.direction,
                            isRead: old.isRead,
                            attachments: old.attachments,
                            replyMessage: old.replyMessage,
                            isPinned: old.isPinned,
                            isImportant: old.isImportant,
                            isDeleted: old.isDeleted,
                            isEdited: true,
                            sticker: old.sticker,
                            senderName: old.senderName,
                            senderAvatarURL: old.senderAvatarURL
                        )
                    }
                }
                self.cancelEditing()
            }
        }
    }

    func pinMessage(_ message: Message) {
        service.pin(peerID: peerID, messageID: message.id, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.pinnedMessage = message
                }
            }
        }
    }

    func unpinCurrentMessage() {
        service.unpin(peerID: peerID, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.pinnedMessage = nil
                }
            }
        }
    }

    func toggleImportant(_ message: Message) {
        let newImp = !message.isImportant
        service.markAsImportant(messageIDs: [message.id], important: newImp, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    if let idx = self?.messages.firstIndex(where: { $0.id == message.id }) {
                        let old = self!.messages[idx]
                        self?.messages[idx] = Message(
                            id: old.id,
                            peerId: old.peerId,
                            fromId: old.fromId,
                            text: old.text,
                            date: old.date,
                            direction: old.direction,
                            isRead: old.isRead,
                            attachments: old.attachments,
                            replyMessage: old.replyMessage,
                            isPinned: old.isPinned,
                            isImportant: newImp,
                            isDeleted: old.isDeleted,
                            isEdited: old.isEdited,
                            sticker: old.sticker,
                            senderName: old.senderName,
                            senderAvatarURL: old.senderAvatarURL
                        )
                    }
                }
            }
        }
    }

    func deleteMessage(_ id: Int, deleteForAll: Bool = true) {
        service.delete(peerID: peerID, messageIDs: [id], deleteForAll: deleteForAll, groupId: nil) { [weak self] result in
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

    func deleteSelected(deleteForAll: Bool = true) {
        let ids = Array(selectedMessageIds)
        service.delete(peerID: peerID, messageIDs: ids, deleteForAll: deleteForAll, groupId: nil) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.messages.removeAll { self?.selectedMessageIds.contains($0.id) ?? false }
                    self?.clearSelection()
                }
            }
        }
    }

    func toggleReaction(_ emoji: String, on messageId: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if messageReactions[messageId] == emoji {
                messageReactions.removeValue(forKey: messageId)
            } else {
                messageReactions[messageId] = emoji
            }
        }
        HapticManager.impact(.light)
    }

    func flashMessage(_ id: Int) {
        scrollToMessageId = id
        withAnimation(.easeInOut(duration: 0.2)) {
            highlightedMessageId = id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            withAnimation(.easeInOut(duration: 0.4)) {
                if self?.highlightedMessageId == id {
                    self?.highlightedMessageId = nil
                }
            }
        }
    }

    func clusterPosition(for index: Int) -> MessageClusterPosition {
        guard index >= 0 && index < messages.count else { return .single }
        let current = messages[index]
        if current.sticker != nil { return .single }

        let hasAbove: Bool = {
            let nextIndex = index + 1
            guard nextIndex < messages.count else { return false }
            let aboveMsg = messages[nextIndex]
            return aboveMsg.fromId == current.fromId &&
                aboveMsg.sticker == nil &&
                abs(aboveMsg.date.timeIntervalSince(current.date)) < 300
        }()

        // In inverted scroll: index - 1 is the message visually BELOW
        let hasBelow: Bool = {
            let prevIndex = index - 1
            guard prevIndex >= 0 else { return false }
            let belowMsg = messages[prevIndex]
            return belowMsg.fromId == current.fromId &&
                belowMsg.sticker == nil &&
                abs(belowMsg.date.timeIntervalSince(current.date)) < 300
        }()

        if !hasAbove && !hasBelow {
            return .single
        } else if !hasAbove && hasBelow {
            return .top
        } else if hasAbove && hasBelow {
            return .middle
        } else {
            return .bottom
        }
    }

    private func markLastAsRead() {
        guard let first = messages.first else { return }
        service.markAsRead(peerID: peerID, startMessageId: first.id, messageIDs: nil, groupId: nil) { _ in }
    }

    private func handleLongPollEvent(_ event: LongPollEvent) {
        switch event {
        case .newMessage(let id, let flags, let eventPeerId, let date, let text, _, let fromId, _):
            guard eventPeerId == peerID else { return }
            let isOut = (flags & 2) != 0

            if messages.contains(where: { $0.id == id }) { return }

            let msg = Message(
                id: id,
                peerId: peerID,
                fromId: fromId,
                text: text,
                date: date,
                direction: isOut ? .outgoing : .incoming,
                isRead: false
            )
            withAnimation(.easeInOut(duration: 0.2)) {
                messages.insert(msg, at: 0)
            }
            markLastAsRead()

        case .editMessage(let id, let eventPeerId, let text, _):
            guard eventPeerId == peerID else { return }
            if let idx = messages.firstIndex(where: { $0.id == id }) {
                let old = messages[idx]
                messages[idx] = Message(
                    id: old.id,
                    peerId: old.peerId,
                    fromId: old.fromId,
                    text: text,
                    date: old.date,
                    direction: old.direction,
                    isRead: old.isRead,
                    attachments: old.attachments,
                    replyMessage: old.replyMessage,
                    isPinned: old.isPinned,
                    isImportant: old.isImportant,
                    isDeleted: old.isDeleted,
                    isEdited: true,
                    sticker: old.sticker,
                    senderName: old.senderName,
                    senderAvatarURL: old.senderAvatarURL
                )
            }

        case .messageDeleted(let id, let eventPeerId):
            guard eventPeerId == peerID else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                messages.removeAll { $0.id == id }
            }

        case .typing(let eventPeerId, _):
            guard eventPeerId == peerID else { return }
            isPeerTyping = true
            peerTypingText = "печатает..."
            typingResetTimer?.cancel()
            typingResetTimer = Just(())
                .delay(for: .seconds(5), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.isPeerTyping = false
                    self?.peerTypingText = nil
                }

        default:
            break
        }
    }
}
