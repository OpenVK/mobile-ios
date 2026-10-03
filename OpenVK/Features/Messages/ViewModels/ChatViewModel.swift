import Foundation
import SwiftUI

enum ChatScrollRequest: Equatable {
    case initial(messageID: Int?)
    case message(messageID: Int)
    case bottom(animated: Bool)
}

private struct SavedChatPosition: Codable {
    let messageID: Int
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = false
    private(set) var isLoadingOlder = false
    private(set) var isLoadingNewer = false
    @Published var errorMessage: String?
    @Published var typingText: String?
    @Published private(set) var stickerPacks: [VKStickerPack] = []
    @Published private(set) var isLoadingStickerPacks = false
    @Published private(set) var isPeerOnline: Bool
    @Published private(set) var peerLastSeen: Date?
    @Published private(set) var canSendMessages: Bool
    @Published private(set) var scrollRequest: ChatScrollRequest = .initial(messageID: nil)
    @Published private(set) var scrollRequestID = 0
    @Published private(set) var isNearBottom = true
    @Published private(set) var unreadMessageCount: Int

    let conversation: Conversation
    private let service: MessagesServiceProtocol
    let pageSize = 40
    private var offset = 0
    private var totalCount = 0
    private var hasMore = true
    private var observer: NSObjectProtocol?
    private var lastTypingSentAt = Date.distantPast
    private var typingExpirations: [Int: Date] = [:]
    private var typingNames: [Int: String] = [:]
    private var didLoadMessages = false
    private var lastRememberedMessageID: Int?
    private var visibleMessageID: Int?
    private var historyAnchorID: Int?
    private var newestLoadedMessageID: Int?
    private var pendingScrollRequestID: Int?

    var canLoadOlderPage: Bool {
        hasMore && !messages.isEmpty && !isLoading && !isLoadingOlder && !isLoadingNewer
            && pendingScrollRequestID == nil
    }

    var canLoadNewerPage: Bool {
        historyAnchorID != nil && newestLoadedMessageID != nil
            && !isLoading && !isLoadingOlder && !isLoadingNewer
            && pendingScrollRequestID == nil
    }
    private var historyRequestToken = 0
    private var cachePositionTask: Task<Void, Never>?

    private var positionStorageKey: String {
        let host = AppConfig.currentHost
        let userID = AuthService.shared.currentUser?.uid ?? 0
        return "openvk.chat.position.\(host).\(userID).\(conversation.id)"
    }

    init(conversation: Conversation, service: MessagesServiceProtocol = MessagesService.shared) {
        self.conversation = conversation
        self.service = service
        isPeerOnline = conversation.peer.isOnline
        peerLastSeen = nil
        canSendMessages = !conversation.isChat || conversation.isChatMember
        unreadMessageCount = conversation.unreadCount
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func load() {
        guard !isLoading, !isLoadingOlder else { return }
        // A restored page is anchored to a message. Refreshing from offset 0 here
        // would join two non-adjacent ranges and break subsequent pagination.
        if didLoadMessages && historyAnchorID != nil { return }
        isLoading = true
        errorMessage = nil
        historyRequestToken &+= 1
        let requestToken = historyRequestToken
        let isInitialLoad = !didLoadMessages
        let savedMessageID = isInitialLoad ? savedPosition()?.messageID : nil
        let anchorID = savedMessageID.flatMap { $0 > 0 ? $0 : nil }
        let initialOffset = anchorID == nil ? 0 : -(pageSize / 2)
        if isInitialLoad,
           let cachedPage = service.cachedHistory(peerID: conversation.id, offset: initialOffset, count: pageSize, startMessageID: anchorID, reverse: false),
           anchorID == nil || cachedPage.messages.contains(where: { $0.id == anchorID }) {
            applyCachedPage(cachedPage, anchorID: anchorID, savedMessageID: savedMessageID)
        }
        service.fetchHistory(peerID: conversation.id, offset: initialOffset, count: pageSize, startMessageID: anchorID, reverse: false) { [weak self] result in
            guard let self, self.historyRequestToken == requestToken else { return }
            switch result {
            case .success(let page):
                if isInitialLoad, let anchorID,
                   !page.messages.contains(where: { $0.id == anchorID }) {
                    if self.messages.contains(where: { $0.id == anchorID }) {
                        self.isLoading = false
                        return
                    }
                    self.loadLatestAfterMissingAnchor()
                    return
                }
                let existingIDs = Set(self.messages.map(\.id))
                let wasShowingCachedPage = isInitialLoad && self.didLoadMessages
                let newIncomingMessageArrived = !isInitialLoad && page.messages.contains {
                    !existingIDs.contains($0.id) && !$0.isOutgoing
                }
                let overlapsCachedPage = !Set(self.messages.map(\.id)).isDisjoint(with: page.messages.map(\.id))
                self.messages = isInitialLoad && !wasShowingCachedPage
                    ? self.mergingTransientMessages(into: page.messages)
                    : wasShowingCachedPage && !overlapsCachedPage
                        ? self.messages
                        : self.mergingLoadedMessages(page.messages)
                self.prefetchMedia(for: page.messages)
                self.didLoadMessages = true
                if newIncomingMessageArrived {
                    HapticManager.playMessageSound()
                    if self.isNearBottom {
                        self.requestScroll(.bottom(animated: true))
                    }
                }
                if page.messages.contains(where: { $0.endsChatParticipation }) {
                    self.canSendMessages = false
                }
                self.totalCount = page.count
                if isInitialLoad {
                    if wasShowingCachedPage && !overlapsCachedPage {
                        self.historyAnchorID = self.messages.last(where: { $0.id > 0 })?.id
                    } else {
                        self.historyAnchorID = self.olderHistoryAnchor(for: page, requestedAnchor: anchorID)
                        self.newestLoadedMessageID = self.messages.last(where: { $0.id > 0 })?.id
                    }
                    self.isNearBottom = self.historyAnchorID == nil
                    self.offset = self.messages.filter { $0.id > 0 }.count
                    self.hasMore = self.offset < self.totalCount && !self.messages.isEmpty
                    if !wasShowingCachedPage {
                        self.requestScroll(.initial(messageID: savedMessageID))
                    }
                } else {
                    self.offset = self.messages.filter { $0.id > 0 }.count
                    self.hasMore = self.offset < self.totalCount && !page.messages.isEmpty
                }
                if self.historyAnchorID == nil {
                    self.service.markAsRead(peerID: self.conversation.id)
                }
            case .failure(let error): self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    @discardableResult
    func loadOlderIfNeeded(message: ChatMessage) -> Bool {
        guard message.id == messages.first?.id, hasMore, !isLoading, !isLoadingOlder, !isLoadingNewer,
              pendingScrollRequestID == nil else { return false }
        isLoadingOlder = true
        let boundaryID = message.id
        let requestToken = historyRequestToken
        if let cachedPage = service.cachedHistory(peerID: conversation.id, offset: 1, count: pageSize, startMessageID: boundaryID, reverse: false),
           isValidBoundaryPage(cachedPage, boundaryID: boundaryID, newer: false) {
            insertOlder(cachedPage)
            isLoadingOlder = false
            return true
        }
        service.fetchHistory(peerID: conversation.id, offset: 1, count: pageSize, startMessageID: boundaryID, reverse: false) { [weak self] result in
            guard let self, self.historyRequestToken == requestToken else { return }
            if case .success(let page) = result {
                guard self.isValidBoundaryPage(page, boundaryID: boundaryID, newer: false) else {
                    self.isLoadingOlder = false
                    return
                }
                self.insertOlder(page)
                self.isLoadingOlder = false
                return
            }
            self.isLoadingOlder = false
        }
        return true
    }

    @discardableResult
    func loadNewerIfNeeded() -> Bool {
        guard historyAnchorID != nil, let newestID = newestLoadedMessageID,
              !isLoading, !isLoadingOlder, !isLoadingNewer,
              pendingScrollRequestID == nil else { return false }
        isLoadingNewer = true
        let requestToken = historyRequestToken
        if let cachedPage = service.cachedHistory(peerID: conversation.id, offset: 1, count: pageSize, startMessageID: newestID, reverse: true),
           isValidBoundaryPage(cachedPage, boundaryID: newestID, newer: true),
           cachedPage.count > cachedPage.messages.count + 1 {
            insertNewer(cachedPage)
            isLoadingNewer = false
            return true
        }
        service.fetchHistory(peerID: conversation.id, offset: 1, count: pageSize, startMessageID: newestID, reverse: true) { [weak self] result in
            guard let self, self.historyRequestToken == requestToken else { return }
            switch result {
            case .success(let page):
                if self.isValidBoundaryPage(page, boundaryID: newestID, newer: true) {
                    self.insertNewer(page)
                }
            case .failure(let error): self.errorMessage = error.localizedDescription
            }
            self.isLoadingNewer = false
        }
        return true
    }

    func send(text: String, replyTo: Int? = nil) {
        guard canSendMessages else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let replyMessage = replyTo.flatMap { id in messages.first(where: { $0.id == id }) }
        let pendingMessage = ChatMessage.pending(text: value, replyTo: replyMessage)
        messages.append(pendingMessage)
        requestScroll(.bottom(animated: true))

        service.sendMessage(peerID: conversation.id, text: value, replyTo: replyTo) { [weak self] result in
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

    func edit(message: ChatMessage, text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard message.isOutgoing, message.id > 0, !value.isEmpty else { return }
        service.editMessage(peerID: conversation.id, messageID: message.id, text: value) { [weak self] result in
            guard case .success = result, let self,
                  let index = self.messages.firstIndex(where: { $0.id == message.id }) else { return }
            self.messages[index] = self.messages[index].updatingText(value)
        }
    }

    func delete(message: ChatMessage, forAll: Bool) {
        guard message.id > 0 else { return }
        service.deleteMessage(peerID: conversation.id, messageID: message.id, forAll: forAll) { [weak self] result in
            guard case .success = result, let self,
                  let index = self.messages.firstIndex(where: { $0.id == message.id }) else { return }
            self.messages[index] = self.messages[index].markingDeleted()
        }
    }

    func loadStickerPacks() {
        guard stickerPacks.isEmpty, !isLoadingStickerPacks else { return }
        if let cachedPacks = service.cachedStickerPacks() {
            stickerPacks = cachedPacks
            prefetchStickerMedia(for: cachedPacks)
        }
        isLoadingStickerPacks = true
        service.fetchStickerPacks { [weak self] result in
            guard let self else { return }
            if case .success(let packs) = result {
                self.stickerPacks = packs
                self.prefetchStickerMedia(for: packs)
            }
            self.isLoadingStickerPacks = false
        }
    }

    func send(sticker: VKSticker) {
        guard canSendMessages else { return }
        guard let stickerID = sticker.identifier else { return }
        let pendingMessage = ChatMessage.pending(sticker: sticker)
        messages.append(pendingMessage)
        requestScroll(.bottom(animated: true))

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

    func rememberPosition(messageID: Int) {
        guard !isLoading, pendingScrollRequestID == nil,
              messageID > 0, messageID != lastRememberedMessageID,
              messages.contains(where: { $0.id == messageID }) else { return }
        visibleMessageID = messageID
        lastRememberedMessageID = messageID
        cachePositionTask?.cancel()
        cachePositionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.persistVisiblePosition()
        }
    }

    func cacheCurrentPosition() {
        cachePositionTask?.cancel()
        cachePositionTask = nil
        guard let messageID = visibleMessageID else { return }
        persistVisiblePosition()
        let loadedMessages = messages.filter { message in
            message.id > 0 && (newestLoadedMessageID.map { message.id <= $0 } ?? true)
        }
        guard let index = loadedMessages.firstIndex(where: { $0.id == messageID }) else { return }

        let newestIndex = min(loadedMessages.count - 1, index + pageSize / 2)
        let oldestIndex = max(0, newestIndex - pageSize + 1)
        let pageMessages = Array(loadedMessages[oldestIndex...newestIndex])
        let newerLoadedCount = loadedMessages.count - newestIndex - 1
        let pageCount = max(pageMessages.count, totalCount - newerLoadedCount)
        let page = MessagesPage(count: pageCount, messages: pageMessages)
        service.cacheHistory(
            page: page,
            peerID: conversation.id,
            offset: -(pageSize / 2),
            count: pageSize,
            startMessageID: messageID,
            reverse: false
        )
    }

    private func persistVisiblePosition() {
        guard let messageID = visibleMessageID,
              let data = try? JSONEncoder().encode(SavedChatPosition(messageID: messageID)) else { return }
        UserDefaults.standard.set(data, forKey: positionStorageKey)
    }

    func updateIsNearBottom(_ value: Bool) {
        let newValue = historyAnchorID == nil && value
        if isNearBottom != newValue { isNearBottom = newValue }
    }

    func scrollToBottom(animated: Bool = false) {
        unreadMessageCount = 0
        if historyAnchorID == nil {
            requestScroll(.bottom(animated: animated))
        } else {
            loadLatest(animated: animated)
        }
    }

    func scrollTo(messageID: Int) {
        if messages.contains(where: { $0.id == messageID }) {
            requestScroll(.message(messageID: messageID))
        } else if messageID > 0 {
            loadAround(messageID: messageID)
        }
    }

    func completeScroll(requestID: Int) {
        if pendingScrollRequestID == requestID {
            pendingScrollRequestID = nil
        }
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
                } else if type == 13 {
                    self.handleDeletedMessageEvent(note)
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

    private func handleDeletedMessageEvent(_ note: Notification) {
        guard let peerID = note.userInfo?["peerID"] as? Int,
              peerID == conversation.id,
              let messageID = note.userInfo?["messageID"] as? Int,
              let index = messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }
        messages[index] = messages[index].markingDeleted()
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
            guard let name = typingNames[ids[0]] else {
                typingText = nil
                return
            }
            typingText = "\(name) печатает"
        } else if count == 2 {
            guard let first = typingNames[ids[0]], let second = typingNames[ids[1]] else {
                typingText = nil
                return
            }
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
            .sorted(by: messageOrder)
    }

    private func mergingLoadedMessages(_ loadedMessages: [ChatMessage]) -> [ChatMessage] {
        var messagesByID: [Int: ChatMessage] = [:]
        for message in messages where message.deliveryStatus != .sending && message.deliveryStatus != .failed {
            messagesByID[message.id] = message
        }
        for message in loadedMessages {
            messagesByID[message.id] = message
        }
        let transientMessages = messages.filter {
            $0.deliveryStatus == .sending || $0.deliveryStatus == .failed
        }
        return (Array(messagesByID.values) + transientMessages)
            .sorted(by: messageOrder)
    }

    private func messageOrder(_ first: ChatMessage, _ second: ChatMessage) -> Bool {
        if first.id > 0 && second.id > 0 { return first.id < second.id }
        if first.date != second.date { return first.date < second.date }
        return first.id < second.id
    }

    private func applyCachedPage(_ page: MessagesPage, anchorID: Int?, savedMessageID: Int?) {
        messages = mergingTransientMessages(into: page.messages)
        didLoadMessages = true
        historyAnchorID = olderHistoryAnchor(for: page, requestedAnchor: anchorID)
        newestLoadedMessageID = page.messages.last?.id
        isNearBottom = historyAnchorID == nil
        offset = page.messages.count
        totalCount = page.count
        hasMore = offset < totalCount && !page.messages.isEmpty
        prefetchMedia(for: page.messages)
        requestScroll(.initial(messageID: savedMessageID))
    }

    private func olderHistoryAnchor(for page: MessagesPage, requestedAnchor: Int?) -> Int? {
        guard requestedAnchor != nil, let newestID = page.messages.last?.id else { return nil }
        return newestID
    }

    private func loadLatestAfterMissingAnchor() {
        UserDefaults.standard.removeObject(forKey: positionStorageKey)
        lastRememberedMessageID = nil
        loadLatest(animated: false)
    }

    private func loadLatest(animated: Bool) {
        isLoading = true
        isLoadingOlder = false
        isLoadingNewer = false
        historyRequestToken &+= 1
        let requestToken = historyRequestToken
        if let cachedPage = service.cachedHistory(peerID: conversation.id, offset: 0, count: pageSize, startMessageID: nil, reverse: false) {
            messages = mergingTransientMessages(into: cachedPage.messages)
            didLoadMessages = true
            historyAnchorID = nil
            newestLoadedMessageID = cachedPage.messages.last?.id
            isNearBottom = true
            offset = cachedPage.messages.count
            totalCount = cachedPage.count
            hasMore = offset < totalCount && !cachedPage.messages.isEmpty
            requestScroll(.bottom(animated: animated))
        }
        service.fetchHistory(peerID: conversation.id, offset: 0, count: pageSize, startMessageID: nil, reverse: false) { [weak self] result in
            guard let self, self.historyRequestToken == requestToken else { return }
            switch result {
            case .success(let page):
                self.messages = self.mergingTransientMessages(into: page.messages)
                self.didLoadMessages = true
                self.historyAnchorID = nil
                self.newestLoadedMessageID = page.messages.last?.id
                self.isNearBottom = true
                self.offset = page.messages.count
                self.totalCount = page.count
                self.hasMore = self.offset < self.totalCount && !page.messages.isEmpty
                self.prefetchMedia(for: page.messages)
                self.requestScroll(.bottom(animated: animated))
                self.service.markAsRead(peerID: self.conversation.id)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    private func loadAround(messageID: Int) {
        isLoading = true
        isLoadingOlder = false
        isLoadingNewer = false
        historyRequestToken &+= 1
        let requestToken = historyRequestToken
        let requestedOffset = -(pageSize / 2)
        if let cachedPage = service.cachedHistory(peerID: conversation.id, offset: requestedOffset, count: pageSize, startMessageID: messageID, reverse: false),
           cachedPage.messages.contains(where: { $0.id == messageID }) {
            applyPageAround(cachedPage, messageID: messageID)
        }
        service.fetchHistory(peerID: conversation.id, offset: requestedOffset, count: pageSize, startMessageID: messageID, reverse: false) { [weak self] result in
            guard let self, self.historyRequestToken == requestToken else { return }
            switch result {
            case .success(let page):
                if page.messages.contains(where: { $0.id == messageID }) {
                    self.applyPageAround(page, messageID: messageID)
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    private func applyPageAround(_ page: MessagesPage, messageID: Int) {
        messages = mergingTransientMessages(into: page.messages)
        historyAnchorID = olderHistoryAnchor(for: page, requestedAnchor: messageID)
        newestLoadedMessageID = page.messages.last?.id
        isNearBottom = historyAnchorID == nil
        offset = page.messages.count
        totalCount = page.count
        hasMore = offset < totalCount && !page.messages.isEmpty
        prefetchMedia(for: page.messages)
        requestScroll(.message(messageID: messageID))
    }

    private func insertOlder(_ page: MessagesPage) {
        let existing = Set(messages.map(\.id))
        let newMessages = page.messages.filter { !existing.contains($0.id) }
        messages.insert(contentsOf: newMessages, at: 0)
        offset += newMessages.count
        hasMore = page.count > page.messages.count + 1 && !page.messages.isEmpty
        prefetchMedia(for: page.messages)
    }

    private func insertNewer(_ page: MessagesPage) {
        let existingIDs = Set(messages.map(\.id))
        let uniqueMessages = page.messages.filter { !existingIDs.contains($0.id) }
        if !uniqueMessages.isEmpty {
            messages.append(contentsOf: uniqueMessages)
            messages.sort(by: messageOrder)
            prefetchMedia(for: uniqueMessages)
        }
        newestLoadedMessageID = page.messages.last?.id ?? newestLoadedMessageID
        totalCount += page.messages.count
        if page.count <= page.messages.count + 1 {
            historyAnchorID = nil
            offset = messages.filter { $0.id > 0 }.count
            hasMore = offset < totalCount
            service.markAsRead(peerID: conversation.id)
        }
    }

    private func isValidBoundaryPage(_ page: MessagesPage, boundaryID: Int, newer: Bool) -> Bool {
        guard page.messages.count <= pageSize,
              page.count >= page.messages.count + 1 else { return false }
        for (index, message) in page.messages.enumerated() {
            guard message.id > 0,
                  (newer ? message.id > boundaryID : message.id < boundaryID) else { return false }
            if index > 0 && page.messages[index - 1].id >= message.id { return false }
        }
        return true
    }

    private func prefetchMedia(for messages: [ChatMessage]) {
        let urls: [URL] = messages.flatMap { message -> [URL] in
            [message.senderAvatarURL, message.stickerURL].compactMap { $0 }
                + message.photos.map(\.url)
                + message.videos.compactMap(\.thumbnailURL)
        }
        DispatchQueue.global(qos: .utility).async {
            ImageCache.shared.prefetchPermanently(urls)
        }
    }

    private func prefetchStickerMedia(for packs: [VKStickerPack]) {
        let urls = packs.flatMap { pack in
            [pack.coverURL] + (pack.stickers ?? []).compactMap(\.thumbnailURL)
        }.compactMap { $0 }
        ImageCache.shared.prefetchPermanently(urls)
    }

    private func requestScroll(_ request: ChatScrollRequest) {
        scrollRequest = request
        scrollRequestID &+= 1
        pendingScrollRequestID = scrollRequestID
    }

    private func savedPosition() -> SavedChatPosition? {
        if let data = UserDefaults.standard.data(forKey: positionStorageKey),
           let position = try? JSONDecoder().decode(SavedChatPosition.self, from: data) {
            return position
        }
        if let messageID = UserDefaults.standard.object(forKey: positionStorageKey) as? Int {
            return SavedChatPosition(messageID: messageID)
        }
        return nil
    }
}
