import SwiftUI
import Lottie
import Foundation
import UIKit
import PhotosUI

private struct PendingChatPhoto: Identifiable {
    let id = UUID()
    let thumbnail: UIImage
    let data: Data
}

struct RecentStickerStore {
    private let defaults: UserDefaults
    private let host: String
    private let limit = 32

    init(defaults: UserDefaults = .standard, host: String = AppConfig.currentHost) {
        self.defaults = defaults
        self.host = host
    }

    func load(userID: Int) -> [VKSticker] {
        guard userID > 0,
              let data = defaults.data(forKey: key(userID: userID)),
              let stickers = try? JSONDecoder().decode([VKSticker].self, from: data) else { return [] }
        var seen = Set<Int>()
        return Array(stickers.filter { sticker in
            guard let id = sticker.identifier else { return false }
            return seen.insert(id).inserted
        }.prefix(limit))
    }

    func record(_ sticker: VKSticker, userID: Int) -> [VKSticker] {
        guard userID > 0, let id = sticker.identifier else { return [] }
        let recent = Array(([sticker] + load(userID: userID).filter { $0.identifier != id }).prefix(limit))
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: key(userID: userID))
        }
        return recent
    }

    private func key(userID: Int) -> String {
        "openvk.recent_stickers.\(host).\(userID)"
    }
}

private struct ChatComposerHeightPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ChatView: View {
    let conversation: Conversation
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: ChatViewModel
    @State private var text = ""
    @State private var legacyTextHeight: CGFloat = 36
    @State private var isEmojiPanelPresented = false
    @State private var recentStickers: [VKSticker] = []
    @State private var selectedVideo: ChatVideo?
    @State private var profileToShow: User?
    @State private var selectedWallPost: ChatWallPost?
    @State private var showsChatInfo = false
    @State private var replyToMessage: ChatMessage?
    @State private var editingMessage: ChatMessage?
    @State private var messageToDelete: ChatMessage?
    @State private var showsPhotoPicker = false
    @State private var selectedPhotos: [PendingChatPhoto] = []
    @State private var composerOverlayHeight: CGFloat = 0
    @FocusState private var isComposerFocused: Bool
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(
        conversation: Conversation,
        viewModel: ChatViewModel? = nil,
        selectedMedia: Binding<Attachment?> = .constant(nil),
        owningPost: Binding<Post?> = .constant(nil)
    ) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: viewModel ?? ChatViewModel(conversation: conversation))
        _selectedMedia = selectedMedia
        _owningPost = owningPost
    }

    var body: some View {
        GeometryReader { geometry in
            if #available(iOS 26.0, *) {
                ZStack(alignment: .bottom) {
                    tableMessageHistory(viewportWidth: geometry.size.width, showsJumpButton: false)
                        .scrollEdgeEffectStyle(nil, for: [.top, .bottom])
                        .ignoresSafeArea(.container, edges: [.top, .bottom])

                    Group {
                        if viewModel.canSendMessages {
                            messageComposer(maxHeight: geometry.size.height / 2)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                        } else {
                            Text("Вы больше не можете отправлять сообщения")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.thinMaterial, in: Capsule())
                                .padding(.bottom, 10)
                        }
                    }
                    .background(GeometryReader { composerGeometry in
                        Color.clear.preference(key: ChatComposerHeightPreference.self, value: composerGeometry.size.height)
                    })

                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .overlay(alignment: .bottomTrailing) {
                    if !viewModel.isNearBottom {
                        jumpToLatestButton
                            .padding(.trailing, 16)
                            .padding(.bottom, max(56, composerOverlayHeight) + 12)
                    }
                }
                .onPreferenceChange(ChatComposerHeightPreference.self) { composerOverlayHeight = $0 }
            } else {
                tableMessageHistory(viewportWidth: geometry.size.width)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if viewModel.canSendMessages {
                        legacyMessageComposer
                        } else {
                            Text("Вы больше не можете отправлять сообщения")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 12)
                        }
                    }
            }
        }
        .background {
            ChatWallpaperBackground()
                .ignoresSafeArea()
        }
        .onChange(of: text) { viewModel.sendTyping(for: $0) }
        .onAppear {
            if let userID = AuthService.shared.currentUser?.uid {
                recentStickers = RecentStickerStore().load(userID: userID)
            }
            if #unavailable(iOS 16.0) {
                LegacyChatTabBarHider.setTabBarHidden(true)
            }
        }
        .onDisappear {
            viewModel.cacheCurrentPosition()
            if #unavailable(iOS 16.0) {
                LegacyChatTabBarHider.setTabBarHidden(false)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { viewModel.cacheCurrentPosition() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .chatNavigationBarBackground()
        .chatTabBarHidden()
        .chatTitleToolbar {
            chatToolbarTitle
        }
        .task {
            viewModel.load()
            viewModel.startListening()
        }
        .background(profileNavigationLink)
        .background(chatInfoNavigationLink)
        .background(wallPostNavigationLink)
        .alert("Не удалось загрузить сообщения", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("ОК", role: .cancel) {}
        } message: { Text(viewModel.errorMessage ?? "Попробуйте ещё раз") }
        .sheet(isPresented: $showsPhotoPicker) {
            ChatPhotoPicker(isPresented: $showsPhotoPicker, selectionLimit: max(1, 10 - selectedPhotos.count)) { photos in
                selectedPhotos.append(contentsOf: photos.prefix(max(0, 10 - selectedPhotos.count)))
            }
        }
        .confirmationDialog("Удалить сообщение?", isPresented: Binding(
            get: { messageToDelete != nil },
            set: { if !$0 { messageToDelete = nil } }
        )) {
            if let messageToDelete {
                Button("Удалить для себя", role: .destructive) {
                    viewModel.delete(message: messageToDelete, forAll: false)
                    self.messageToDelete = nil
                }
                if messageToDelete.isOutgoing {
                    Button("Удалить у всех", role: .destructive) {
                        viewModel.delete(message: messageToDelete, forAll: true)
                        self.messageToDelete = nil
                    }
                }
            }
            Button("Отмена", role: .cancel) { messageToDelete = nil }
        }
        .fullScreenCover(item: $selectedVideo) { video in
            ChatVideoPlayer(video: video)
        }
    }

    private var chatToolbarTitle: some View {
        Group {
            if conversation.isChat {
                Button {
                    showsChatInfo = true
                } label: {
                    chatTitle
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Информация о беседе")
            } else {
                Button {
                    profileToShow = conversation.peer
                } label: {
                    chatTitle
                }
                .buttonStyle(.plain)
            }
        }
        .chatToolbarCapsule(animationToken: toolbarCapsuleAnimationToken)
    }

    private var chatTitle: some View {
        HStack(spacing: 8) {
            Avatar(
                user: conversation.peer,
                size: 28,
                placeholderImageName: conversation.isChat ? "chat_default_100" : nil,
                isChat: conversation.isChat
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(conversation.peer.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                if let typing = viewModel.typingText {
                    TypingStatusView(text: typing)
                } else if conversation.isChat, let count = conversation.chatMemberCount {
                    Text("\(count) \(memberCountWord(count))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let presence = viewModel.peerPresenceText {
                    Text(presence)
                        .font(.caption2)
                        .foregroundStyle(viewModel.isPeerOnline ? Color.appAccent : .secondary)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private var toolbarCapsuleAnimationToken: String {
        let subtitle: String
        if let typing = viewModel.typingText {
            subtitle = typing
        } else if conversation.isChat, let count = conversation.chatMemberCount {
            subtitle = "\(count) \(memberCountWord(count))"
        } else {
            subtitle = viewModel.peerPresenceText ?? ""
        }
        return "\(conversation.peer.displayName)|\(subtitle)"
    }

    private func memberCountWord(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "участников" }
        if last == 1 { return "участник" }
        if (2...4).contains(last) { return "участника" }
        return "участников"
    }

    private func tableMessageHistory(viewportWidth: CGFloat, showsJumpButton: Bool = true) -> some View {
        ChatTableHistory(
            messages: viewModel.messages,
            stickerPickerPresented: isEmojiPanelPresented,
            bottomOverlayHeight: {
                if #available(iOS 26.0, *) { return composerOverlayHeight }
                return 0
            }(),
            pageSize: viewModel.pageSize,
            scrollRequest: viewModel.scrollRequest,
            scrollRequestID: viewModel.scrollRequestID,
            rowContent: { index in
                let message = viewModel.messages[index]
                return AnyView(
                    MessageBubble(
                        message: message,
                        isChat: conversation.isChat,
                        viewportWidth: viewportWidth,
                        showsSenderDetails: shouldShowSenderDetails(for: index),
                        joinsPrevious: joinsMessage(at: index, with: index - 1),
                        joinsNext: joinsMessage(at: index, with: index + 1),
                        onPhotoTap: { openPhotoViewer(for: $0) },
                        onVideoTap: { selectedVideo = $0 },
                        onWallTap: { selectedWallPost = $0 },
                        onProfileTap: { profileToShow = $0 },
                        onMentionTap: { openProfile(forMention: $0) },
                        onReply: { message in
                            replyToMessage = message
                            editingMessage = nil
                            isComposerFocused = true
                        },
                        onReplyTap: { viewModel.scrollTo(messageID: $0.messageID) },
                        onEdit: { message in
                            editingMessage = message
                            replyToMessage = nil
                            text = message.text
                            isComposerFocused = true
                        },
                        onDelete: { messageToDelete = $0 }
                    )
                    .id(message.id)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 1)
                )
            },
            onVisible: { id, nearBottom in
                viewModel.rememberPosition(messageID: id)
                viewModel.updateIsNearBottom(nearBottom)
            },
            canLoadOlder: { viewModel.canLoadOlderPage },
            canLoadNewer: { viewModel.canLoadNewerPage },
            onLoadOlder: { viewModel.loadOlderIfNeeded(message: $0) },
            onLoadNewer: { viewModel.loadNewerIfNeeded() },
            onScrollCompleted: { viewModel.completeScroll(requestID: $0) },
            onTapBackground: dismissChatKeyboard
        )
        .overlay(alignment: .bottomTrailing) {
            if showsJumpButton && !viewModel.isNearBottom {
                jumpToLatestButton
                .padding(.trailing, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var jumpToLatestButton: some View {
        Button {
            viewModel.scrollToBottom(animated: true)
        } label: {
            ZStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold))
                if viewModel.unreadMessageCount > 0 {
                    Text("\(viewModel.unreadMessageCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.appAccent, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 7, y: -7)
                }
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .chatJumpButtonGlass()
        .accessibilityLabel("К последним сообщениям")
    }

    private var profileNavigationLink: some View {
        NavigationLink(
            destination: Group {
                if let profileToShow {
                    ProfileView(
                        user: profileToShow,
                        selectedMedia: $selectedMedia,
                        owningPost: $owningPost
                    )
                }
            },
            isActive: Binding(
                get: { profileToShow != nil },
                set: { if !$0 { profileToShow = nil } }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    private var chatInfoNavigationLink: some View {
        NavigationLink(
            destination: ChatInfoView(conversation: conversation),
            isActive: $showsChatInfo
        ) {
            EmptyView()
        }
        .hidden()
    }

    private var wallPostNavigationLink: some View {
        NavigationLink(
            destination: Group {
                if let wall = selectedWallPost {
                    PostDetailLoaderView(
                        ownerID: wall.postReference?.ownerID ?? 0,
                        postID: wall.postReference?.postID ?? 0,
                        selectedMedia: $selectedMedia,
                        owningPost: $owningPost
                    )
                }
            },
            isActive: Binding(
                get: { selectedWallPost != nil },
                set: { if !$0 { selectedWallPost = nil } }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    private func shouldShowSenderDetails(for index: Int) -> Bool {
        !joinsMessage(at: index, with: index - 1)
    }

    private func joinsMessage(at index: Int, with neighborIndex: Int) -> Bool {
        guard viewModel.messages.indices.contains(index), viewModel.messages.indices.contains(neighborIndex) else {
            return false
        }
        let message = viewModel.messages[index]
        let neighbor = viewModel.messages[neighborIndex]
        return message.systemEventText == nil && neighbor.systemEventText == nil
            && message.senderID == neighbor.senderID
            && message.isOutgoing == neighbor.isOutgoing
    }

    @available(iOS 26.0, *)
    private func messageComposer(maxHeight: CGFloat) -> some View {
        let maximumLines = max(1, Int((maxHeight - 20) / 22))

        return VStack(spacing: 8) {
            if let editingMessage {
                messageActionBanner(title: "Редактирование сообщения", subtitle: editingMessage.text) {
                    self.editingMessage = nil
                    text = ""
                }
            } else if let replyToMessage {
                messageActionBanner(title: "Ответ: \(replyToMessage.senderName ?? "Пользователь")", subtitle: replyToMessage.text) {
                    self.replyToMessage = nil
                }
            }
            if !selectedPhotos.isEmpty {
                selectedPhotoPreview
            }
            composerControls(maximumLines: maximumLines)

            if isEmojiPanelPresented {
                StickerPickerPanel(
                    packs: viewModel.stickerPacks,
                    recentStickers: recentStickers,
                    isLoading: viewModel.isLoadingStickerPacks,
                    onStickerSelected: sendSticker
                )
                    .frame(height: min(280, maxHeight - 56))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isEmojiPanelPresented)
        .onChange(of: isEmojiPanelPresented) { isPresented in
            guard isPresented else { return }
            viewModel.loadStickerPacks()
        }
    }

    @available(iOS 26.0, *)
    private func composerControls(maximumLines: Int) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button { openPhotoPicker() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Добавить вложение")
            .disabled(selectedPhotos.count >= 10 || viewModel.isSendingPhotos || editingMessage != nil)

            TextField("Сообщение", text: $text, axis: .vertical)
                .font(.body)
                .lineLimit(1...maximumLines)
                .focused($isComposerFocused)
                .disabled(viewModel.isSendingPhotos)
                .padding(.leading, 14)
                .padding(.trailing, 48)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .trailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isEmojiPanelPresented.toggle()
                            isComposerFocused = !isEmojiPanelPresented
                        }
                    } label: {
                        Image(systemName: isEmojiPanelPresented ? "keyboard" : "face.smiling")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Эмодзи")
                }

            if viewModel.isSendingPhotos {
                ProgressView()
                    .frame(width: 25, height: 25)
            } else if hasSendableContent {
                Button {
                    sendComposedMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 25, height: 25)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(Color.appAccent)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Отправить сообщение")
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: hasSendableContent)
        .onChange(of: isComposerFocused) { isFocused in
            if isFocused {
                isEmojiPanelPresented = false
            }
        }
    }

    private var hasMessageText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasSendableContent: Bool {
        hasMessageText || (!selectedPhotos.isEmpty && editingMessage == nil)
    }

    private var legacyMessageComposer: some View {
        VStack(spacing: 0) {
            Divider()
            if let editingMessage {
                messageActionBanner(title: "Редактирование сообщения", subtitle: editingMessage.text) {
                    self.editingMessage = nil
                    text = ""
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            } else if let replyToMessage {
                messageActionBanner(title: "Ответ: \(replyToMessage.senderName ?? "Пользователь")", subtitle: replyToMessage.text) {
                    self.replyToMessage = nil
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            if !selectedPhotos.isEmpty {
                selectedPhotoPreview
            }
            HStack(spacing: 4) {
                Button(action: openPhotoPicker) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.appAccent)
                }
                .disabled(selectedPhotos.count >= 10 || viewModel.isSendingPhotos || editingMessage != nil)
                .padding(.leading, 5)
                .accessibilityLabel("Добавить фотографии")

                legacyMessageInput

                if viewModel.isSendingPhotos {
                    ProgressView()
                        .padding(.trailing, 8)
                } else if hasSendableContent {
                    Button(action: sendLegacyMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.appAccent)
                    }
                    .padding(.trailing, 4)
                    .padding(.vertical, 4)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Отправить сообщение")
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(18)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: hasSendableContent)

            if isEmojiPanelPresented {
                StickerPickerPanel(
                    packs: viewModel.stickerPacks,
                    recentStickers: recentStickers,
                    isLoading: viewModel.isLoadingStickerPacks,
                    onStickerSelected: sendSticker
                )
                .frame(height: 280)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(.bar)
        .animation(.easeInOut(duration: 0.15), value: isEmojiPanelPresented)
    }

    private var legacyMessageInput: some View {
        ZStack(alignment: .trailing) {
            CommentTextView(
                text: $text,
                placeholder: "Сообщение",
                height: $legacyTextHeight,
                onBeginEditing: closeLegacyStickerPicker
            )
                .disabled(viewModel.isSendingPhotos)
                .padding(.trailing, 38)
                .frame(height: min(legacyTextHeight, 120))

            Button(action: toggleLegacyStickerPicker) {
                Image(systemName: isEmojiPanelPresented ? "keyboard" : "face.smiling")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Стикеры")
        }
    }

    private func toggleLegacyStickerPicker() {
        endEditing()
        withAnimation(.easeInOut(duration: 0.15)) {
            isEmojiPanelPresented.toggle()
        }
        if isEmojiPanelPresented {
            viewModel.loadStickerPacks()
        }
    }

    private func closeLegacyStickerPicker() {
        guard isEmojiPanelPresented else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            isEmojiPanelPresented = false
        }
    }

    private func endEditing() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.endEditing(true) }
    }

    private func dismissChatKeyboard() {
        isComposerFocused = false
        endEditing()
    }

    private func sendLegacyMessage() {
        sendComposedMessage()
    }

    private var selectedPhotoPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedPhotos) { photo in
                    Image(uiImage: photo.thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(alignment: .topTrailing) {
                            if !viewModel.isSendingPhotos {
                                Button {
                                    selectedPhotos.removeAll { $0.id == photo.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white, .black.opacity(0.7))
                                }
                                .offset(x: 5, y: -5)
                                .accessibilityLabel("Убрать фотографию")
                            }
                        }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .frame(height: 82)
    }

    private func openPhotoPicker() {
        guard selectedPhotos.count < 10, !viewModel.isSendingPhotos else { return }
        dismissChatKeyboard()
        isEmojiPanelPresented = false
        showsPhotoPicker = true
    }

    private func sendComposedMessage() {
        guard !viewModel.isSendingPhotos else { return }
        let value = text
        if let editingMessage {
            guard hasMessageText else { return }
            viewModel.edit(message: editingMessage, text: value)
            self.editingMessage = nil
            text = ""
            legacyTextHeight = 36
        } else if !selectedPhotos.isEmpty {
            let photos = selectedPhotos.map(\.data)
            viewModel.sendPhotos(text: value, photos: photos, replyTo: replyToMessage?.id) { success in
                guard success else { return }
                selectedPhotos.removeAll()
                text = ""
                replyToMessage = nil
                legacyTextHeight = 36
            }
        } else if hasMessageText {
            text = ""
            legacyTextHeight = 36
            viewModel.send(text: value, replyTo: replyToMessage?.id)
            replyToMessage = nil
        }
    }

    @ViewBuilder
    private func messageActionBanner(title: String, subtitle: String, cancel: @escaping () -> Void) -> some View {
        if #available(iOS 26.0, *) {
            messageActionBannerContent(title: title, subtitle: subtitle, cancel: cancel)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            messageActionBannerContent(title: title, subtitle: subtitle, cancel: cancel)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func messageActionBannerContent(title: String, subtitle: String, cancel: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold))
                Text(subtitle.isEmpty ? "Вложение" : subtitle)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(action: cancel) { Image(systemName: "xmark.circle.fill") }
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func sendSticker(_ sticker: VKSticker) {
        viewModel.send(sticker: sticker)
        if let userID = AuthService.shared.currentUser?.uid {
            recentStickers = RecentStickerStore().record(sticker, userID: userID)
        }
    }

    private func openPhotoViewer(for photo: ChatPhoto) {
        let photos = viewModel.messages.flatMap(\.allPhotos)
        let attachments = photos.map {
            Attachment.remoteImage(
                url: $0.url.absoluteString,
                id: nil,
                ownerID: nil,
                likesCount: 0,
                commentsCount: 0,
                repostsCount: 0,
                isLiked: false
            )
        }
        var author = conversation.peer
        author.photoCount = photos.count

        guard let index = photos.firstIndex(of: photo), attachments.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            owningPost = Post(author: author, timeAgo: "", text: "", attachments: attachments)
            selectedMedia = attachments[index]
        }
    }

    private func openProfile(forMention username: String) {
        ProfileService.shared.fetchProfile(username: username) { result in
            if case .success(let user) = result {
                profileToShow = user
            }
        }
    }

}

private struct ChatTableHistory: UIViewRepresentable {
    let messages: [ChatMessage]
    let stickerPickerPresented: Bool
    let bottomOverlayHeight: CGFloat
    let pageSize: Int
    let scrollRequest: ChatScrollRequest
    let scrollRequestID: Int
    let rowContent: (Int) -> AnyView
    let onVisible: (Int, Bool) -> Void
    let canLoadOlder: () -> Bool
    let canLoadNewer: () -> Bool
    let onLoadOlder: (ChatMessage) -> Bool
    let onLoadNewer: () -> Bool
    let onScrollCompleted: (Int) -> Void
    let onTapBackground: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITableView {
        let table = UITableView(frame: .zero, style: .plain)
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.register(ChatMessageTableCell.self, forCellReuseIdentifier: ChatMessageTableCell.reuseID)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 56
        table.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        table.contentInsetAdjustmentBehavior = .never
        table.keyboardDismissMode = .interactive
        table.tableFooterView = UIView(frame: .zero)
        if #available(iOS 26.0, *) {
            table.topEdgeEffect.isHidden = true
            table.bottomEdgeEffect.isHidden = true
        }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTapBackground))
        tap.cancelsTouchesInView = false
        table.addGestureRecognizer(tap)
        context.coordinator.tableView = table
        return table
    }

    func updateUIView(_ table: UITableView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(to: table)
    }

    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var parent: ChatTableHistory
        weak var tableView: UITableView?
        private var displayedMessages: [ChatMessage] = []
        private var lastHandledScrollRequestID = 0
        private var lastWidth: CGFloat = 0
        private var lastUserOffsetY: CGFloat = 0
        private var scrollSequence = 0
        private var suppressScrollCallbacks = false
        private var pendingVisibleReport = false
        private var wasStickerPickerPresented = false
        private var measuredHeights: [Int: CGFloat] = [:]
        private let loadGate = ChatPageLoadGate()

        init(parent: ChatTableHistory) { self.parent = parent }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            displayedMessages.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ChatMessageTableCell.reuseID, for: indexPath
            ) as! ChatMessageTableCell
            cell.configure(content: parent.rowContent(indexPath.row), parentController: tableView.chatParentController())
            return cell
        }

        func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
            guard displayedMessages.indices.contains(indexPath.row) else { return 56 }
            let message = displayedMessages[indexPath.row]
            if let height = measuredHeights[message.id] { return height }
            if message.stickerURL != nil { return 170 }
            if !(message.forwardedMessages ?? []).isEmpty { return 220 }
            if let attachments = message.richAttachments {
                if attachments.contains(where: { if case .wall = $0 { return true }; return false }) { return 280 }
                if attachments.contains(where: { if case .audio = $0 { return true }; return false }) {
                    return CGFloat(75 + attachments.count * 70)
                }
                if attachments.contains(where: {
                    switch $0 {
                    case .poll, .link, .sticker, .unsupported: return true
                    default: return false
                    }
                }) { return 140 }
            }
            if !message.photos.isEmpty || !message.videos.isEmpty || !message.gifs.isEmpty { return 220 }
            if !message.documents.isEmpty { return 100 }
            if message.systemEventText != nil { return 48 }
            return 56
        }

        func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            guard displayedMessages.indices.contains(indexPath.row) else { return }
            measuredHeights[displayedMessages[indexPath.row].id] = cell.bounds.height
        }

        func apply(to table: UITableView) {
            suppressScrollCallbacks = true
            let pickerJustOpened = parent.stickerPickerPresented && !wasStickerPickerPresented
            wasStickerPickerPresented = parent.stickerPickerPresented
            let safeArea = table.window?.safeAreaInsets ?? UIApplication.shared.firstKeyWindow?.safeAreaInsets ?? .zero
            let desiredTopInset: CGFloat
            let desiredBottomInset: CGFloat
            if #available(iOS 26.0, *) {
                let navigationBarHeight = table.chatParentController()?.navigationController?.navigationBar.bounds.height ?? 56
                desiredTopInset = 10 + safeArea.top + navigationBarHeight
                desiredBottomInset = 20 + safeArea.bottom + max(56, parent.bottomOverlayHeight)
            } else {
                desiredTopInset = 10
                desiredBottomInset = 10 + parent.bottomOverlayHeight
            }
            if abs(table.contentInset.top - desiredTopInset) > 0.5 {
                table.contentInset.top = desiredTopInset
                table.verticalScrollIndicatorInsets.top = desiredTopInset
            }
            if abs(table.contentInset.bottom - desiredBottomInset) > 0.5 {
                table.contentInset.bottom = desiredBottomInset
                table.verticalScrollIndicatorInsets.bottom = desiredBottomInset
            }
            let next = parent.messages
            let oldIDs = displayedMessages.map(\.id)
            let newIDs = next.map(\.id)
            let oldAnchor = visibleAnchor(in: table)
            if abs(lastWidth - table.bounds.width) > 1 { measuredHeights.removeAll() }
            for (old, updated) in zip(displayedMessages, next) where old.id == updated.id && old != updated {
                measuredHeights.removeValue(forKey: old.id)
            }
            if oldIDs.isEmpty {
                displayedMessages = next
                table.reloadData()
            } else if newIDs != oldIDs,
                      newIDs.count > oldIDs.count,
                      Array(newIDs.suffix(oldIDs.count)) == oldIDs {
                let insertedCount = newIDs.count - oldIDs.count
                displayedMessages = next
                UIView.performWithoutAnimation {
                    table.beginUpdates()
                    table.insertRows(at: (0..<insertedCount).map { IndexPath(row: $0, section: 0) }, with: .none)
                    table.endUpdates()
                    table.layoutIfNeeded()
                    if let oldAnchor, let index = next.firstIndex(where: { $0.id == oldAnchor.id }) {
                        restore(anchor: oldAnchor, at: index, in: table)
                    }
                }
                refreshVisibleCells(in: table)
            } else if newIDs != oldIDs,
                      newIDs.count > oldIDs.count,
                      Array(newIDs.prefix(oldIDs.count)) == oldIDs {
                displayedMessages = next
                UIView.performWithoutAnimation {
                    table.beginUpdates()
                    table.insertRows(
                        at: (oldIDs.count..<newIDs.count).map { IndexPath(row: $0, section: 0) },
                        with: .none
                    )
                    table.endUpdates()
                }
                refreshVisibleCells(in: table)
            } else if newIDs != oldIDs {
                displayedMessages = next
                table.reloadData()
                table.layoutIfNeeded()
                if let oldAnchor, let newIndex = next.firstIndex(where: { $0.id == oldAnchor.id }) {
                    restore(anchor: oldAnchor, at: newIndex, in: table)
                }
            } else if displayedMessages != next || abs(lastWidth - table.bounds.width) > 1 {
                displayedMessages = next
                UIView.performWithoutAnimation {
                    refreshVisibleCells(in: table)
                    table.beginUpdates()
                    table.endUpdates()
                    table.layoutIfNeeded()
                    if let oldAnchor, let index = next.firstIndex(where: { $0.id == oldAnchor.id }) {
                        restore(anchor: oldAnchor, at: index, in: table)
                    }
                }
            }
            lastWidth = table.bounds.width
            handleScrollRequest(in: table)
            lastUserOffsetY = table.contentOffset.y
            suppressScrollCallbacks = false
            reportVisiblePosition(in: table)
            if pickerJustOpened {
                // Wait for the composer to finish resizing before revealing the
                // latest message above the sticker picker.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self, weak table] in
                    guard let self, let table, self.parent.stickerPickerPresented,
                          !self.displayedMessages.isEmpty else { return }
                    table.layoutIfNeeded()
                    let bottom = max(-table.adjustedContentInset.top,
                                     table.contentSize.height - table.bounds.height + table.adjustedContentInset.bottom)
                    table.setContentOffset(CGPoint(x: table.contentOffset.x, y: bottom), animated: false)
                }
            }
        }

        private func refreshVisibleCells(in table: UITableView) {
            for indexPath in table.indexPathsForVisibleRows ?? [] {
                guard displayedMessages.indices.contains(indexPath.row),
                      let cell = table.cellForRow(at: indexPath) as? ChatMessageTableCell else { continue }
                cell.configure(content: parent.rowContent(indexPath.row), parentController: table.chatParentController())
            }
        }

        private func visibleAnchor(in table: UITableView) -> (id: Int, y: CGFloat)? {
            guard let index = table.indexPathsForVisibleRows?.map(\.row).min(),
                  displayedMessages.indices.contains(index) else { return nil }
            let y = table.rectForRow(at: IndexPath(row: index, section: 0)).minY - table.contentOffset.y
            return (displayedMessages[index].id, y)
        }

        private func restore(anchor: (id: Int, y: CGFloat), at index: Int, in table: UITableView) {
            let rect = table.rectForRow(at: IndexPath(row: index, section: 0))
            let target = rect.minY - anchor.y
            table.setContentOffset(CGPoint(x: table.contentOffset.x, y: target), animated: false)
        }

        private func handleScrollRequest(in table: UITableView) {
            let requestID = parent.scrollRequestID
            guard requestID != 0,
                  requestID != lastHandledScrollRequestID,
                  !displayedMessages.isEmpty else { return }
            let row: Int
            let position: UITableView.ScrollPosition
            let animated: Bool
            switch parent.scrollRequest {
            case .initial(let savedID):
                row = savedID.flatMap { id in displayedMessages.firstIndex(where: { $0.id == id }) }
                    ?? displayedMessages.count - 1
                position = savedID == nil ? .bottom : .top
                animated = false
            case .message(let id):
                guard let index = displayedMessages.firstIndex(where: { $0.id == id }) else { return }
                row = index
                position = .middle
                animated = false
            case .bottom(let shouldAnimate):
                row = displayedMessages.count - 1
                position = .bottom
                animated = shouldAnimate
            }
            lastHandledScrollRequestID = requestID
            table.layoutIfNeeded()
            if position == .bottom {
                let bottom = max(
                    -table.adjustedContentInset.top,
                    table.contentSize.height - table.bounds.height + table.adjustedContentInset.bottom
                )
                table.setContentOffset(CGPoint(x: table.contentOffset.x, y: bottom), animated: animated)
            } else {
                table.scrollToRow(at: IndexPath(row: row, section: 0), at: position, animated: animated)
            }
            parent.onScrollCompleted(requestID)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            lastUserOffsetY = scrollView.contentOffset.y
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !suppressScrollCallbacks,
                  let table = tableView,
                  !displayedMessages.isEmpty else { return }
            reportVisiblePosition(in: table)
            let currentY = scrollView.contentOffset.y
            let movement = currentY - lastUserOffsetY
            lastUserOffsetY = currentY
            guard (scrollView.isDragging || scrollView.isDecelerating), abs(movement) > 1 else { return }
            scrollSequence &+= 1
            let direction: ChatScrollDirection = movement < 0 ? .older : .newer
            let userScroll = ChatUserScroll(direction: direction, sequence: scrollSequence)
            guard let visible = table.indexPathsForVisibleRows, !visible.isEmpty else { return }
            let firstVisible = visible.map(\.row).min() ?? 0
            let lastVisible = visible.map(\.row).max() ?? 0
            if let first = displayedMessages.first,
               parent.canLoadOlder(),
               loadGate.shouldLoadOlder(
                   boundaryID: first.id,
                   pageVisible: firstVisible < parent.pageSize,
                   userScroll: userScroll
               ) {
                loadGate.didStartOlder(boundaryID: first.id, sequence: scrollSequence)
                let callback = parent.onLoadOlder
                DispatchQueue.main.async { [weak self] in
                    if !callback(first) { self?.loadGate.cancelOlder(boundaryID: first.id) }
                }
            }
            if let last = displayedMessages.last,
               parent.canLoadNewer(),
               loadGate.shouldLoadNewer(
                   boundaryID: last.id,
                   pageVisible: lastVisible >= max(0, displayedMessages.count - parent.pageSize),
                   userScroll: userScroll
               ) {
                loadGate.didStartNewer(boundaryID: last.id, sequence: scrollSequence)
                let callback = parent.onLoadNewer
                DispatchQueue.main.async { [weak self] in
                    if !callback() { self?.loadGate.cancelNewer(boundaryID: last.id) }
                }
            }
        }

        private func reportVisiblePosition(in table: UITableView) {
            guard !pendingVisibleReport else { return }
            pendingVisibleReport = true
            DispatchQueue.main.async { [weak self, weak table] in
                guard let self, let table else { return }
                self.pendingVisibleReport = false
                guard let first = table.indexPathsForVisibleRows?.map(\.row).min(),
                      self.displayedMessages.indices.contains(first) else { return }
                let bottom = max(
                    -table.adjustedContentInset.top,
                    table.contentSize.height - table.bounds.height + table.adjustedContentInset.bottom
                )
                let nearBottom = table.contentOffset.y >= bottom - 32
                self.parent.onVisible(self.displayedMessages[first].id, nearBottom)
            }
        }

        @objc func didTapBackground() { parent.onTapBackground() }
    }
}

private final class ChatMessageTableCell: UITableViewCell {
    static let reuseID = "chat-message"
    private var host: UIHostingController<AnyView>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let width = max(targetSize.width, contentView.bounds.width, superview?.bounds.width ?? 0)
        guard let host, width > 0 else {
            return super.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: horizontalFittingPriority,
                verticalFittingPriority: verticalFittingPriority
            )
        }
        let size = host.sizeThatFits(in: CGSize(width: width, height: .infinity))
        if #available(iOS 16.4, *) {
            return CGSize(width: width, height: max(1, ceil(size.height)))
        }
        let safeAreaHeight = host.view.safeAreaInsets.top + host.view.safeAreaInsets.bottom
        return CGSize(width: width, height: max(1, ceil(size.height - safeAreaHeight)))
    }

    func configure(content: AnyView, parentController: UIViewController?) {
        if let host {
            if host.parent == nil, let parentController {
                parentController.addChild(host)
                host.didMove(toParent: parentController)
            }
            if #available(iOS 16.4, *) {
                host.rootView = content
            } else {
                host.rootView = AnyView(content.ignoresSafeArea())
            }
            host.view.invalidateIntrinsicContentSize()
            return
        }
        let host: UIHostingController<AnyView>
        if #available(iOS 16.4, *) {
            host = UIHostingController(rootView: content)
            host.safeAreaRegions = []
        } else {
            host = UIHostingController(rootView: AnyView(content.ignoresSafeArea()))
        }
        host.view.backgroundColor = .clear
        host.view.clipsToBounds = true
        host.view.translatesAutoresizingMaskIntoConstraints = false
        parentController?.addChild(host)
        contentView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        if parentController != nil { host.didMove(toParent: parentController) }
        self.host = host
    }
}

private extension UIView {
    func chatParentController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}

enum ChatScrollDirection {
    case older
    case newer
}

struct ChatUserScroll {
    let direction: ChatScrollDirection
    let sequence: Int
}

final class ChatPageLoadGate {
    private var lastOlderBoundaryID: Int?
    private var lastNewerBoundaryID: Int?
    private var lastOlderSequence = 0
    private var lastNewerSequence = 0

    func shouldLoadOlder(boundaryID: Int, pageVisible: Bool, userScroll: ChatUserScroll?) -> Bool {
        guard pageVisible else {
            if lastOlderBoundaryID == boundaryID { lastOlderBoundaryID = nil }
            return false
        }
        guard let userScroll, userScroll.direction == .older else { return false }
        return boundaryID != lastOlderBoundaryID && userScroll.sequence > lastOlderSequence
    }

    func shouldLoadNewer(boundaryID: Int, pageVisible: Bool, userScroll: ChatUserScroll?) -> Bool {
        guard pageVisible else {
            if lastNewerBoundaryID == boundaryID { lastNewerBoundaryID = nil }
            return false
        }
        guard let userScroll, userScroll.direction == .newer else { return false }
        return boundaryID != lastNewerBoundaryID && userScroll.sequence > lastNewerSequence
    }

    func didStartOlder(boundaryID: Int, sequence: Int) {
        lastOlderBoundaryID = boundaryID
        lastOlderSequence = sequence
    }

    func didStartNewer(boundaryID: Int, sequence: Int) {
        lastNewerBoundaryID = boundaryID
        lastNewerSequence = sequence
    }

    func cancelOlder(boundaryID: Int) {
        if lastOlderBoundaryID == boundaryID { lastOlderBoundaryID = nil }
    }

    func cancelNewer(boundaryID: Int) {
        if lastNewerBoundaryID == boundaryID { lastNewerBoundaryID = nil }
    }
}

private struct StickerPickerPanel: View {
    let packs: [VKStickerPack]
    let recentStickers: [VKSticker]
    let isLoading: Bool
    let onStickerSelected: (VKSticker) -> Void

    private let grid = [GridItem(.adaptive(minimum: 62), spacing: 6)]

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                packTabs { sectionID in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(sectionID, anchor: .top)
                    }
                }
                Divider()
                content
            }
        }
        .chatStickerPickerSurface()
    }

    private func packTabs(onSelect: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if !recentStickers.isEmpty {
                    Button { onSelect("recent") } label: {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Недавние")
                }
                ForEach(packs) { pack in
                    Button { onSelect(sectionID(for: pack)) } label: {
                        if let cover = pack.stickers?.first {
                            StickerPickerArtwork(sticker: cover)
                                .frame(width: 30, height: 30)
                        } else {
                            stickerImage(url: pack.coverURL)
                                .frame(width: 30, height: 30)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(pack.displayName)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && packs.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if packs.isEmpty && recentStickers.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "face.smiling")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Нет стикерпаков")
                    .font(.subheadline.weight(.semibold))
                Text("Установленные стикерпаки появятся здесь.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !recentStickers.isEmpty {
                        stickerSection(title: "Недавние", stickers: recentStickers)
                            .id("recent")
                    }
                    ForEach(packs) { pack in
                        stickerSection(title: pack.displayName, stickers: pack.stickers ?? [])
                            .id(sectionID(for: pack))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    private func stickerSection(title: String, stickers: [VKSticker]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: grid, spacing: 6) {
                ForEach(stickers, id: \.identifier) { sticker in
                    Button { onStickerSelected(sticker) } label: {
                        StickerPickerArtwork(sticker: sticker)
                            .frame(width: 62, height: 62)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionID(for pack: VKStickerPack) -> String {
        "pack-\(pack.id)"
    }

    @ViewBuilder
    private func stickerImage(url: URL?) -> some View {
        if let url {
            CachedRemoteImage(url: url, contentMode: .fit) { ProgressView() }
        } else {
            Image(systemName: "face.smiling").foregroundStyle(.secondary)
        }
    }
}

private struct StickerPickerArtwork: View {
    let sticker: VKSticker

    var body: some View {
        if let url = sticker.thumbnailURL {
            CachedRemoteImage(url: url, contentMode: .fit) { ProgressView() }
        } else {
            Image(systemName: "face.smiling").foregroundStyle(.secondary)
        }
    }
}

extension View {
    @ViewBuilder func chatTitleToolbar<Title: View>(@ViewBuilder title: @escaping () -> Title) -> some View {
        if #available(iOS 26.0, *) {
            self.toolbar {
                ToolbarItem(placement: .principal) { title() }
                    .sharedBackgroundVisibility(.hidden)
            }
        } else {
            self.toolbar {
                ToolbarItem(placement: .principal) { title() }
            }
        }
    }

    @ViewBuilder func chatStickerPickerSurface() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            self
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder func chatJumpButtonGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: Circle())
        } else {
            self.background(.thinMaterial, in: Circle())
        }
    }

    @ViewBuilder func chatToolbarCapsule(animationToken: String) -> some View {
        if #available(iOS 26.0, *) {
            self
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: Capsule())
                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: animationToken)
        } else {
            self
        }
    }

    @ViewBuilder func chatNavigationBarBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.toolbarBackgroundVisibility(.visible, for: .navigationBar)
        } else if #available(iOS 18.0, *) {
            self.toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else if #available(iOS 16.0, *) {
            self.toolbarBackground(.hidden, for: .navigationBar)
        } else {
            self
        }
    }

    @ViewBuilder func chatTabBarHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .tabBar)
        } else {
            self.background(LegacyChatTabBarHider())
        }
    }

    @ViewBuilder func chatScrollKeyboardDismissal() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

struct LegacyChatTabBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.setTabBarHidden(true)
    }

    static func dismantleUIViewController(_ uiViewController: Controller, coordinator: ()) {
        uiViewController.setTabBarHidden(false)
    }

    static func setTabBarHidden(_ hidden: Bool) {
        DispatchQueue.main.async {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
            for window in windows {
                guard let controller = window.rootViewController,
                      let tabBarController = findTabBarController(in: controller) else { continue }
                tabBarController.tabBar.isHidden = hidden
                tabBarController.additionalSafeAreaInsets.bottom = hidden
                    ? -max(0, tabBarController.tabBar.bounds.height - window.safeAreaInsets.bottom)
                    : 0
                tabBarController.view.setNeedsLayout()
            }
        }
    }

    private static func findTabBarController(in controller: UIViewController) -> UITabBarController? {
        if let tabBarController = controller as? UITabBarController {
            return tabBarController
        }
        for child in controller.children {
            if let tabBarController = findTabBarController(in: child) {
                return tabBarController
            }
        }
        if let presented = controller.presentedViewController {
            return findTabBarController(in: presented)
        }
        return nil
    }

    final class Controller: UIViewController {
        private var shouldHideTabBar = false

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            setTabBarHidden(parent != nil)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            if shouldHideTabBar {
                updateTabBarLayout()
            }
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            setTabBarHidden(false)
        }

        func setTabBarHidden(_ hidden: Bool) {
            shouldHideTabBar = hidden
            DispatchQueue.main.async { [weak self] in
                self?.updateTabBarLayout()
            }
        }

        private func updateTabBarLayout() {
            var current: UIViewController? = self
            while let controller = current {
                if let tabBarController = controller.tabBarController {
                    let windowBottomInset = tabBarController.view.window?.safeAreaInsets.bottom ?? 0
                    let bottomInset = shouldHideTabBar
                        ? -max(0, tabBarController.tabBar.bounds.height - windowBottomInset)
                        : 0
                    if tabBarController.tabBar.isHidden != shouldHideTabBar
                        || tabBarController.additionalSafeAreaInsets.bottom != bottomInset {
                        tabBarController.tabBar.isHidden = shouldHideTabBar
                        tabBarController.additionalSafeAreaInsets.bottom = bottomInset
                        tabBarController.view.setNeedsLayout()
                    }
                    return
                }
                current = controller.parent
            }
        }
    }
}

private struct TypingStatusView: View {
    let text: String
    @State private var dotCount = 1

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
            Text(String(repeating: ".", count: dotCount))
                .frame(width: 9, alignment: .leading)
        }
        .font(.caption2)
        .foregroundStyle(Color.appAccent)
        .onReceive(Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()) { _ in
            dotCount = dotCount == 3 ? 1 : dotCount + 1
        }
    }
}

private struct ChatMentionText: View {
    let text: String
    let isOutgoing: Bool
    let isDeleted: Bool
    let onMentionTap: (String) -> Void

    var body: some View {
        Text(attributedText)
            .font(.system(size: 16))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(isOutgoing ? .white : (isDeleted ? .secondary : .primary))
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "openvk-profile", let username = url.host else {
                    return .systemAction
                }
                onMentionTap(username)
                return .handled
            })
    }

    private var attributedText: AttributedString {
        guard !isDeleted,
              let expression = try? NSRegularExpression(
                pattern: "\\[([^\\]|]+)\\|([^\\]]+)\\]|@([A-Za-zА-Яа-яЁё0-9_]+)"
              ) else {
            return AttributedString(text)
        }

        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var result = AttributedString()
        var cursor = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            result.append(AttributedString(String(text[cursor..<range.lowerBound])))

            let identifierRange = match.range(at: 1)
            let displayRange = match.range(at: 2)
            let nicknameRange = match.range(at: 3)
            let identifier: String
            let displayName: String
            if let range = Range(identifierRange, in: text), identifierRange.location != NSNotFound {
                identifier = String(text[range])
                displayName = Range(displayRange, in: text).map { String(text[$0]) } ?? identifier
            } else if let range = Range(nicknameRange, in: text) {
                identifier = String(text[range])
                displayName = "@\(identifier)"
            } else {
                result.append(AttributedString(String(text[range])))
                cursor = range.upperBound
                continue
            }

            var mention = AttributedString(displayName)
            mention.link = URL(string: "openvk-profile://\(identifier)")
            mention.foregroundColor = isOutgoing ? .white : Color.appAccent
            result.append(mention)
            cursor = range.upperBound
        }
        result.append(AttributedString(String(text[cursor...])))
        return result
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isChat: Bool
    let viewportWidth: CGFloat
    let showsSenderDetails: Bool
    let joinsPrevious: Bool
    let joinsNext: Bool
    let onPhotoTap: (ChatPhoto) -> Void
    let onVideoTap: (ChatVideo) -> Void
    let onWallTap: (ChatWallPost) -> Void
    let onProfileTap: (User) -> Void
    let onMentionTap: (String) -> Void
    let onReply: (ChatMessage) -> Void
    let onReplyTap: (ChatReply) -> Void
    let onEdit: (ChatMessage) -> Void
    let onDelete: (ChatMessage) -> Void
    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        Group {
            if let systemEventText = message.systemEventText {
                SystemMessagePlaque(text: systemEventText, date: message.date)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    if message.isOutgoing { Spacer(minLength: 48) }
                    if !message.isOutgoing && isChat {
                        if !joinsNext {
                            Button {
                                onProfileTap(sender)
                            } label: {
                                Avatar(user: sender, size: 26)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(width: 26, height: 26)
                        }
                    }
                    messageContent
                    if !message.isOutgoing { Spacer(minLength: 48) }
                }
            }
        }
        .padding(.top, joinsPrevious ? 0 : 4)
        .contentShape(Rectangle())
        .offset(x: swipeOffset)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: swipeOffset)
        .contextMenu {
            if message.systemEventText == nil {
            if !message.text.isEmpty && !message.isDeleted {
                Button {
                    UIPasteboard.general.string = message.text
                } label: {
                    Label("Копировать", systemImage: "doc.on.doc")
                }
            }
            if !message.isDeleted, message.id > 0 {
                Button {
                    onReply(message)
                } label: {
                    Label("Ответить", systemImage: "arrowshape.turn.up.left")
                }
            }
            if message.isOutgoing, !message.isDeleted, message.id > 0, !message.text.isEmpty {
                Button {
                    onEdit(message)
                } label: {
                    Label("Редактировать", systemImage: "pencil")
                }
            }
            if !message.isDeleted, message.id > 0 {
                Button(role: .destructive) {
                    onDelete(message)
                } label: {
                    Label("Удалить", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 24)
                .onChanged { value in
                    guard message.systemEventText == nil,
                          !message.isDeleted,
                          message.id > 0,
                          abs(value.translation.width) > abs(value.translation.height) else { return }
                    swipeOffset = min(0, max(-84, value.translation.width))
                }
                .onEnded { value in
                    defer { swipeOffset = 0 }
                    guard value.translation.width < -60,
                          abs(value.translation.width) > abs(value.translation.height),
                          message.systemEventText == nil,
                          !message.isDeleted,
                          message.id > 0 else { return }
                    onReply(message)
                }
        )
    }

    @ViewBuilder
    private var messageContent: some View {
        if let stickerURL = message.stickerURL {
            sticker(url: stickerURL, animationURL: message.stickerAnimationURL)
        } else if usesRichAttachmentBubble {
            richAttachmentBubble
        } else if let video = message.videos.first {
            videoBubble(video)
        } else if !message.photos.isEmpty {
            photoBubble
        } else if let gif = message.gifs.first {
            gifBubble(gif)
        } else if !message.documents.isEmpty {
            filesBubble
        } else {
            bubble
        }
    }

    private var usesRichAttachmentBubble: Bool {
        if !(message.forwardedMessages ?? []).isEmpty { return true }
        let attachments = message.richAttachments ?? []
        if attachments.contains(where: {
            switch $0 {
            case .audio, .wall, .poll, .link, .sticker, .unsupported: return true
            case .photo, .video, .document: return false
            }
        }) { return true }
        if attachments.count <= 1 { return false }
        let allPhotos = attachments.allSatisfy { if case .photo = $0 { return true }; return false }
        let allDocuments = attachments.allSatisfy { if case .document = $0 { return true }; return false }
        return !allPhotos && !allDocuments
    }

    private var richAttachmentBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isChat, !message.isOutgoing, showsSenderDetails, let senderName = message.senderName {
                Button { onProfileTap(sender) } label: {
                    Text(senderName).font(.caption.weight(.semibold)).foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
            }
            if let reply = message.reply {
                Button { onReplyTap(reply) } label: {
                    replyPreview(reply, width: photoBubbleWidth - 26)
                }
                .buttonStyle(.plain)
            }
            if !message.text.isEmpty { messageText }
            ForEach(Array((message.richAttachments ?? []).enumerated()), id: \.offset) { _, attachment in
                ChatRichAttachmentCard(
                    attachment: attachment,
                    mediaWidth: photoBubbleWidth - 26,
                    isOutgoing: message.isOutgoing,
                    onPhotoTap: onPhotoTap,
                    onVideoTap: onVideoTap,
                    onWallTap: onWallTap
                )
            }
            ForEach(Array((message.forwardedMessages ?? []).enumerated()), id: \.offset) { _, forwarded in
                ChatForwardedMessageCard(
                    message: forwarded,
                    mediaWidth: photoBubbleWidth - 26,
                    isOutgoing: message.isOutgoing,
                    onPhotoTap: onPhotoTap,
                    onVideoTap: onVideoTap,
                    onWallTap: onWallTap
                )
            }
            HStack {
                Spacer(minLength: 0)
                messageMetadata
            }
        }
        .foregroundStyle(message.isOutgoing ? .white : .primary)
        .padding(13)
        .frame(width: photoBubbleWidth, alignment: .leading)
        .background(attachmentBubbleColor, in: attachmentBubbleShape)
    }

    private var filesBubble: some View {
        VStack(alignment: .leading, spacing: 7) {
            if isChat, !message.isOutgoing, showsSenderDetails, let senderName = message.senderName {
                Button { onProfileTap(sender) } label: {
                    Text(senderName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
            }

            if let reply = message.reply {
                Button { onReplyTap(reply) } label: {
                    replyPreview(reply, width: photoBubbleWidth - 26)
                }
                .buttonStyle(.plain)
            }

            ForEach(message.documents) { document in
                ChatDocumentAttachmentCard(document: document)
            }

            if !message.text.isEmpty {
                messageTextAndMetadata
            } else {
                HStack {
                    Spacer()
                    messageMetadata
                }
            }
        }
        .foregroundStyle(message.isOutgoing ? .white : .primary)
        .padding(13)
        .frame(width: photoBubbleWidth, alignment: .leading)
        .background(attachmentBubbleColor, in: attachmentBubbleShape)
    }

    private func gifBubble(_ gif: ChatDocument) -> some View {
        let size = gifBubbleSize(for: gif)
        return ZStack(alignment: .bottomTrailing) {
            ChatGIFArtwork(url: gif.url)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Анимированное изображение: \(gif.title)")

            imageMetadata
                .padding(6)
        }
    }

    private func gifBubbleSize(for gif: ChatDocument) -> CGSize {
        let maximumWidth = photoBubbleWidth
        let maximumHeight: CGFloat = 300
        let aspectRatio = max(CGFloat(gif.aspectRatio), 0.1)
        let width = min(maximumWidth, maximumHeight * aspectRatio)
        return CGSize(width: width, height: width / aspectRatio)
    }

    private var photoBubble: some View {
        VStack(alignment: .leading, spacing: 3) {
            VStack(spacing: 0) {
                ChatPhotoCollage(photos: message.photos, width: photoBubbleWidth, onTap: onPhotoTap)
                    .clipShape(TopRoundedRectangle(radius: 18))

                if !message.text.isEmpty {
                    photoMessageTextAndMetadata
                        .foregroundStyle(message.isOutgoing ? .white : .primary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(message.isOutgoing ? Color.appAccent : Color(.secondarySystemBackground))
                }
            }
            .frame(width: photoBubbleWidth, alignment: .leading)
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if message.text.isEmpty {
                    imageMetadata
                        .padding(6)
                }
            }
        }
        .background(attachmentBubbleColor, in: attachmentBubbleShape)
    }

    private func videoBubble(_ video: ChatVideo) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            VStack(spacing: 0) {
                Button { onVideoTap(video) } label: {
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let thumbnailURL = video.thumbnailURL {
                                CachedRemoteImage(url: thumbnailURL, contentMode: .fill) {
                                    Color(.secondarySystemBackground)
                                }
                            } else {
                                Color(.secondarySystemBackground)
                            }
                        }
                        .frame(width: photoBubbleWidth, height: 190)
                        .clipped()

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.95))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(video.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(video.durationText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(10)
                    }
                    .frame(width: photoBubbleWidth, height: 190)
                }
                .buttonStyle(.plain)
                .clipShape(TopRoundedRectangle(radius: 18))

                if !message.text.isEmpty {
                    photoMessageTextAndMetadata
                        .foregroundStyle(message.isOutgoing ? .white : .primary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(message.isOutgoing ? Color.appAccent : Color(.secondarySystemBackground))
                }
            }
            .frame(width: photoBubbleWidth, alignment: .leading)
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if message.text.isEmpty {
                    imageMetadata
                        .padding(6)
                }
            }
        }
        .background(attachmentBubbleColor, in: attachmentBubbleShape)
        .accessibilityLabel("Видео: \(video.title)")
    }

    private func sticker(url: URL, animationURL: URL?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            StickerArtwork(staticURL: url, animationURL: animationURL)
                .frame(width: 160, height: 160)

            stickerMetadata
                .padding(4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Стикер, \(message.date.formatted(date: .omitted, time: .shortened))")
    }

    private var attachmentBubbleColor: Color {
        message.isOutgoing ? Color.appAccent : Color(.secondarySystemBackground)
    }

    private var attachmentBubbleShape: MessageBubbleShape {
        MessageBubbleShape(
            topLeadingRadius: 18,
            topTrailingRadius: 18,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            hasTail: !joinsNext && !message.text.isEmpty,
            isOutgoing: message.isOutgoing
        )
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isChat, !message.isOutgoing, showsSenderDetails, let senderName = message.senderName {
                Button {
                    onProfileTap(sender)
                } label: {
                    Text(senderName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
            }

            if let reply = message.reply {
                Button {
                    onReplyTap(reply)
                } label: {
                    replyPreview(reply, width: bubbleContentWidth)
                }
                .buttonStyle(.plain)
            }

            messageTextAndMetadata
                .frame(width: bubbleContentWidth > 0 ? bubbleContentWidth : nil, alignment: .leading)
        }
        .foregroundStyle(message.isOutgoing ? .white : .primary)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(
            message.isOutgoing ? Color.appAccent : Color(.secondarySystemBackground),
            in: MessageBubbleShape(
                topLeadingRadius: message.isOutgoing || !joinsPrevious ? 18 : 8,
                topTrailingRadius: message.isOutgoing && joinsPrevious ? 8 : 18,
                bottomLeadingRadius: message.isOutgoing || !joinsNext ? 18 : 8,
                bottomTrailingRadius: message.isOutgoing && joinsNext ? 8 : 18,
                hasTail: !joinsNext,
                isOutgoing: message.isOutgoing
            )
        )
    }

    private var bubbleContentWidth: CGFloat {
        let text = message.isDeleted ? "Сообщение удалено" : message.text
        let textWidth = text.components(separatedBy: .newlines)
            .map { ($0 as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 16)]).width }
            .max() ?? 0
        let replyWidth: CGFloat
        if let reply = message.reply {
            let font = UIFont.systemFont(ofSize: 12)
            replyWidth = max(
                (reply.senderName as NSString).size(withAttributes: [.font: font]).width,
                (reply.text as NSString).size(withAttributes: [.font: font]).width
            ) + 24
        } else {
            replyWidth = 0
        }
        return min(maximumBubbleContentWidth, ceil(max(textWidth + metadataSlotWidth + 4, replyWidth)))
    }

    private var maximumBubbleContentWidth: CGFloat {
        let reservedWidth: CGFloat = message.isOutgoing ? 72 : (isChat ? 104 : 72)
        return max(0, min(viewportWidth - reservedWidth - 26, 300))
    }

    private func replyPreview(_ reply: ChatReply, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(reply.senderName)
                .font(.caption.weight(.semibold))
            Text(reply.text)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(message.isOutgoing ? .white.opacity(0.85) : Color.appAccent)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .padding(.leading, 8)
        .frame(width: width > 0 ? width : nil, alignment: .leading)
        .background(Color.appAccent.opacity(message.isOutgoing ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Capsule()
                .fill(message.isOutgoing ? Color.white.opacity(0.75) : Color.appAccent)
                .frame(width: 3)
        }
    }

    private var messageText: some View {
        ChatMentionText(
            text: message.isDeleted ? "Сообщение удалено" : message.text,
            isOutgoing: message.isOutgoing,
            isDeleted: message.isDeleted,
            onMentionTap: onMentionTap
        )
    }

    private var photoMessageTextAndMetadata: some View {
        messageText
            .padding(.trailing, metadataSlotWidth)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottomTrailing) {
                messageMetadata.frame(width: metadataSlotWidth, alignment: .trailing)
            }
    }

    private var messageTextAndMetadata: some View {
        messageText
            .frame(width: messageTextWidth, alignment: .leading)
            .padding(.trailing, metadataSlotWidth)
            .padding(.bottom, 14)
            .overlay(alignment: .bottomTrailing) {
                messageMetadata.frame(width: metadataSlotWidth, alignment: .trailing)
            }
    }

    private var messageTextWidth: CGFloat? {
        guard bubbleContentWidth > metadataSlotWidth else { return nil }
        return bubbleContentWidth - metadataSlotWidth
    }

    private var metadataSlotWidth: CGFloat { message.isEdited ? 76 : 50 }

    private var timeLabel: some View {
        Text(message.date, style: .time)
            .font(.system(size: 10))
            .foregroundStyle(message.isOutgoing ? .white.opacity(0.75) : .secondary)
    }

    private var messageMetadata: some View {
        HStack(spacing: 4) {
            if message.isEdited {
                Text("ред.")
                    .font(.system(size: 10))
                    .foregroundStyle(message.isOutgoing ? .white.opacity(0.75) : .secondary)
            }
            timeLabel
            if let status = message.deliveryStatus {
                deliveryStatusLabel(status)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var stickerMetadata: some View {
        HStack(spacing: 4) {
            Text(message.date, style: .time)
                .font(.system(size: 10))
            if let status = message.deliveryStatus {
                deliveryStatusLabel(status)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var imageMetadata: some View {
        HStack(spacing: 4) {
            Text(message.date, style: .time)
                .font(.system(size: 10))
            if let status = message.deliveryStatus {
                deliveryStatusLabel(status)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    @ViewBuilder
    private func deliveryStatusLabel(_ status: MessageDeliveryStatus) -> some View {
        switch status {
        case .sending:
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.65)
                .frame(width: 12, height: 8)
                .tint(.white.opacity(0.75))
                .accessibilityLabel("Отправляется")
        case .unread, .read:
            MessageReadReceiptIcon(isRead: status == .read)
                .accessibilityLabel(status == .read ? "Прочитано" : "Не прочитано")
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.red)
                .accessibilityLabel("Ошибка отправки")
        }
    }

    private var isStickerMessage: Bool {
        message.stickerURL != nil
    }

    private var photoBubbleWidth: CGFloat {
        let reservedWidth: CGFloat = message.isOutgoing ? 72 : (isChat ? 104 : 72)
        return max(0, min(viewportWidth - reservedWidth, 300))
    }

    private var sender: User {
        User(
            uid: message.senderID,
            username: message.senderID < 0
                ? "club\(abs(message.senderID))"
                : "id\(message.senderID)",
            displayName: message.senderName ?? "",
            avatarURL: message.senderAvatarURL,
            isGroup: false
        )
    }
}

private struct ChatRichAttachmentCard: View {
    let attachment: ChatRichAttachment
    let mediaWidth: CGFloat
    let isOutgoing: Bool
    let onPhotoTap: (ChatPhoto) -> Void
    let onVideoTap: (ChatVideo) -> Void
    let onWallTap: (ChatWallPost) -> Void

    @ViewBuilder
    var body: some View {
        switch attachment {
        case .photo(let photo):
            Button { onPhotoTap(photo) } label: {
                CachedRemoteImage(url: photo.url, contentMode: .fill) {
                    Color(.tertiarySystemFill)
                }
                .frame(width: max(1, mediaWidth), height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Фотография")
        case .video(let video):
            Button { onVideoTap(video) } label: {
                ZStack {
                    if let url = video.thumbnailURL {
                        CachedRemoteImage(url: url, contentMode: .fill) {
                            Color(.tertiarySystemFill)
                        }
                        .frame(width: max(1, mediaWidth), height: 160)
                        .clipped()
                    } else {
                        Color(.tertiarySystemFill)
                    }
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.white)
                }
                .frame(width: max(1, mediaWidth), height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Видео: \(video.title)")
        case .audio(let audio):
            Group {
                if let url = audio.url {
                    Link(destination: url) { audioLabel(audio) }
                } else {
                    audioLabel(audio)
                }
            }
            .accessibilityLabel("Аудиозапись: \(audio.artist), \(audio.title)")
        case .document(let document):
            ChatDocumentAttachmentCard(document: document)
        case .wall(let wall):
            wallCard(wall)
        case .poll(let poll):
            VStack(alignment: .leading, spacing: 6) {
                Label("Опрос", systemImage: "chart.bar.fill")
                    .font(.caption.weight(.semibold))
                Text(poll.question).font(.subheadline.weight(.medium))
                ForEach(Array(poll.answers.prefix(5).enumerated()), id: \.offset) { _, answer in
                    Text(answer)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 7))
                }
                Text("Голосов: \(poll.votes)").font(.caption2).opacity(0.7)
            }
            .padding(8)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        case .link(let link):
            Group {
                if let url = link.url {
                    Link(destination: url) { linkLabel(link) }
                } else {
                    linkLabel(link)
                }
            }
        case .sticker(let url):
            CachedRemoteImage(url: url, contentMode: .fit) {
                Color.clear
            }
            .frame(width: 120, height: 120)
        case .unsupported(let type):
            Label("Вложение: \(type)", systemImage: "paperclip")
                .font(.caption)
                .opacity(0.75)
        }
    }

    private func linkLabel(_ link: ChatLink) -> some View {
        Label(link.title, systemImage: "link")
            .font(.subheadline)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
    }

    private func audioLabel(_ audio: ChatAudio) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "play.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOutgoing ? .white : Color.appAccent)
                .frame(width: 38, height: 38)
                .background((isOutgoing ? Color.white : Color.appAccent).opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(audio.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(audio.artist.isEmpty ? "Аудиозапись" : audio.artist)
                    .font(.caption).lineLimit(1).opacity(0.75)
            }
            Spacer(minLength: 0)
            Text(audio.durationText).font(.caption2).opacity(0.75)
        }
        .foregroundStyle(isOutgoing ? Color.white : Color(.label))
        .padding(8)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func wallCard(_ wall: ChatWallPost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let avatarURL = wall.authorAvatarURL {
                    CachedRemoteImage(url: avatarURL, contentMode: .fill) {
                        Color(.tertiarySystemFill)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "text.alignleft")
                        .frame(width: 28, height: 28)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(wall.authorName).font(.caption.weight(.semibold)).lineLimit(1)
                    Text("Запись").font(.caption2).foregroundColor(Color(.secondaryLabel))
                }
                Spacer(minLength: 0)
                if let url = wall.url {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(.label))
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel("Открыть запись")
                }
            }
            if !wall.text.isEmpty {
                Text(wall.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(wall.attachments.enumerated()), id: \.offset) { _, nested in
                ChatRichAttachmentCard(
                    attachment: nested.richAttachment,
                    mediaWidth: mediaWidth - 20,
                    isOutgoing: false,
                    onPhotoTap: onPhotoTap,
                    onVideoTap: onVideoTap,
                    onWallTap: onWallTap
                )
            }
        }
        .foregroundColor(Color(.label))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            Button { onWallTap(wall) } label: {
                Color.clear.contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Открыть запись и комментарии")
        }
    }
}

private struct ChatForwardedMessageCard: View {
    let message: ChatForwardedMessage
    let mediaWidth: CGFloat
    let isOutgoing: Bool
    let onPhotoTap: (ChatPhoto) -> Void
    let onVideoTap: (ChatVideo) -> Void
    let onWallTap: (ChatWallPost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Пересланное сообщение")
                .font(.caption2).foregroundColor(Color(.secondaryLabel))
            Text(message.senderName)
                .font(.caption.weight(.semibold))
            if !message.text.isEmpty {
                Text(message.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(message.attachments.enumerated()), id: \.offset) { _, attachment in
                ChatRichAttachmentCard(
                    attachment: attachment,
                    mediaWidth: mediaWidth - 20,
                    isOutgoing: false,
                    onPhotoTap: onPhotoTap,
                    onVideoTap: onVideoTap,
                    onWallTap: onWallTap
                )
            }
            ForEach(Array(message.forwardedMessages.enumerated()), id: \.offset) { _, forwarded in
                AnyView(ChatForwardedMessageCard(
                    message: forwarded,
                    mediaWidth: mediaWidth - 20,
                    isOutgoing: false,
                    onPhotoTap: onPhotoTap,
                    onVideoTap: onVideoTap,
                    onWallTap: onWallTap
                ))
            }
        }
        .foregroundColor(Color(.label))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct ChatDocumentAttachmentCard: View {
    let document: ChatDocument
    @State private var isDownloading = false

    var body: some View {
        Button {
            DocumentDownloader.downloadAndShare(
                url: document.url,
                title: document.title,
                ext: document.ext,
                isDownloading: $isDownloading
            )
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.appAccent.opacity(0.16))
                    Image(systemName: "doc.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if !document.ext.isEmpty {
                            Text(document.ext.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.appAccent)
                        }
                        if !document.formattedSize.isEmpty {
                            Text(document.formattedSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 4)
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(9)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
        .accessibilityLabel("Документ \(document.title). Открыть или скачать")
    }
}

private struct ChatGIFArtwork: View {
    let url: String
    @State private var isLoaded = false

    var body: some View {
        ZStack {
            GIFView(urlString: url) {
                isLoaded = true
            }

            if !isLoaded {
                ProgressView()
                    .controlSize(.large)
            }
        }
    }
}

private struct StickerArtwork: View {
    let staticURL: URL
    let animationURL: URL?
    @State private var animationIsLoaded = false

    var body: some View {
        ZStack {
            CachedRemoteImage(url: staticURL, contentMode: .fit) {
                ProgressView()
                    .frame(width: 160, height: 160)
            }
            .frame(width: 160, height: 160)
            .opacity(animationURL == nil || !animationIsLoaded ? 1 : 0)

            if let animationURL {
                AnimatedStickerView(animationURL: animationURL) {
                    animationIsLoaded = true
                }
                .frame(width: 160, height: 160)
                .clipped()
                .accessibilityHidden(true)
            }
        }
    }
}

private struct AnimatedStickerView: UIViewRepresentable {
    let animationURL: URL
    let onLoaded: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> LottieStickerContainerView {
        let view = LottieStickerContainerView()
        load(animationURL, into: view.animationView, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: LottieStickerContainerView, context: Context) {
        guard context.coordinator.loadedURL != animationURL else { return }
        load(animationURL, into: view.animationView, coordinator: context.coordinator)
    }

    static func dismantleUIView(_ view: LottieStickerContainerView, coordinator: Coordinator) {
        view.animationView.stop()
    }

    private func load(_ url: URL, into view: LottieAnimationView, coordinator: Coordinator) {
        coordinator.loadedURL = url
        view.stop()
        view.animation = nil
        LottieAnimation.loadedFrom(url: url) { animation in
            DispatchQueue.main.async {
                guard coordinator.loadedURL == url, let animation else { return }
                view.animation = animation
                view.play()
                onLoaded()
            }
        }
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}

private final class LottieStickerContainerView: UIView {
    let animationView = LottieAnimationView()

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .clear

        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundColor = .clear
        animationView.loopMode = .loop
        animationView.backgroundBehavior = .pauseAndRestore
        addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: trailingAnchor),
            animationView.topAnchor.constraint(equalTo: topAnchor),
            animationView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct ChatPhotoCollage: View {
    let photos: [ChatPhoto]
    let width: CGFloat
    let onTap: (ChatPhoto) -> Void

    private var visiblePhotos: [ChatPhoto] { Array(photos.prefix(9)) }
    private var columnCount: Int {
        switch visiblePhotos.count {
        case 1: return 1
        case 2, 4: return 2
        default: return 3
        }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(visiblePhotos) { photo in
                Button { onTap(photo) } label: {
                    CachedRemoteImage(url: photo.url, contentMode: .fit) {
                        Color(.secondarySystemBackground)
                            .overlay { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(CGFloat(photo.aspectRatio), contentMode: .fit)
                    .frame(maxHeight: visiblePhotos.count == 1 ? 300 : 180)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: width)
    }
}

private struct ChatVideoPlayer: View {
    @Environment(\.dismiss) private var dismiss
    let video: ChatVideo
    @State private var selectedQuality = ""
    @State private var cacheToken: UUID?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FullScreenVideoPlayerView(
                title: video.title,
                coverURLString: video.thumbnailURL?.absoluteString ?? "",
                videoURLString: video.playerURL?.absoluteString,
                files: video.files,
                selectedQuality: $selectedQuality,
                isActive: true
            )

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .padding(.top, 18)
            .padding(.trailing, 18)
            .accessibilityLabel("Закрыть видео")
        }
        .onAppear {
            selectedQuality = video.preferredQuality
            if let url = video.preferredURL {
                cacheToken = VideoSegmentCache.shared.startCaching(url)
            }
        }
        .onDisappear {
            if let cacheToken {
                VideoSegmentCache.shared.stopCaching(cacheToken)
            }
        }
    }
}

private struct SystemMessagePlaque: View {
    let text: String
    let date: Date

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
            Text(date, style: .time)
                .font(.system(size: 10))
                .opacity(0.75)
        }
        .font(.footnote)
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
        .frame(maxWidth: .infinity)
    }
}

private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(radius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ChatPhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let selectionLimit: Int
    let onSelect: ([PendingChatPhoto]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: ChatPhotoPicker

        init(parent: ChatPhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            guard !results.isEmpty else { return }

            final class ResultsBox {
                let lock = NSLock()
                var photos: [PendingChatPhoto?]
                init(count: Int) { photos = Array(repeating: nil, count: count) }
            }
            let box = ResultsBox(count: results.count)
            let group = DispatchGroup()

            for (index, result) in results.enumerated() {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard let image = object as? UIImage else { group.leave(); return }
                    DispatchQueue.global(qos: .userInitiated).async {
                        defer { group.leave() }
                        let longSide = max(image.size.width, image.size.height)
                        guard longSide > 0 else { return }
                        let ratio = min(1, 2048 / longSide)
                        let size = CGSize(width: max(1, round(image.size.width * ratio)), height: max(1, round(image.size.height * ratio)))
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = 1
                        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                            image.draw(in: CGRect(origin: .zero, size: size))
                        }
                        guard let data = resized.jpegData(compressionQuality: 0.82) else { return }
                        let scale = max(96 / size.width, 96 / size.height)
                        let previewSize = CGSize(width: size.width * scale, height: size.height * scale)
                        let thumbnail = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format).image { _ in
                            resized.draw(in: CGRect(
                                x: (96 - previewSize.width) / 2,
                                y: (96 - previewSize.height) / 2,
                                width: previewSize.width,
                                height: previewSize.height
                            ))
                        }
                        box.lock.lock()
                        box.photos[index] = PendingChatPhoto(thumbnail: thumbnail, data: data)
                        box.lock.unlock()
                    }
                }
            }

            group.notify(queue: .main) {
                self.parent.onSelect(box.photos.compactMap { $0 })
            }
        }
    }
}

private struct MessageBubbleShape: Shape {
    let topLeadingRadius: CGFloat
    let topTrailingRadius: CGFloat
    let bottomLeadingRadius: CGFloat
    let bottomTrailingRadius: CGFloat
    let hasTail: Bool
    let isOutgoing: Bool

    func path(in rect: CGRect) -> Path {
        let maximumRadius = min(rect.width, rect.height) / 2
        let topLeading = min(topLeadingRadius, maximumRadius)
        let topTrailing = min(topTrailingRadius, maximumRadius)
        let bottomLeading = min(bottomLeadingRadius, maximumRadius)
        let bottomTrailing = min(bottomTrailingRadius, maximumRadius)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + topLeading, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topTrailing, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - topTrailing, y: rect.minY + topTrailing), radius: topTrailing, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailing))
        if hasTail && isOutgoing {
            path.addCurve(
                to: CGPoint(x: rect.maxX + 5, y: rect.maxY - 6),
                control1: CGPoint(x: rect.maxX + 1, y: rect.maxY - 4),
                control2: CGPoint(x: rect.maxX + 5, y: rect.maxY - 5)
            )
            path.addCurve(
                to: CGPoint(x: rect.maxX - 12, y: rect.maxY),
                control1: CGPoint(x: rect.maxX + 2, y: rect.maxY - 3),
                control2: CGPoint(x: rect.maxX - 6, y: rect.maxY + 1)
            )
        } else {
            path.addArc(center: CGPoint(x: rect.maxX - bottomTrailing, y: rect.maxY - bottomTrailing), radius: bottomTrailing, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + (hasTail && !isOutgoing ? 12 : bottomLeading), y: rect.maxY))
        if hasTail && !isOutgoing {
            path.addCurve(
                to: CGPoint(x: rect.minX - 5, y: rect.maxY - 6),
                control1: CGPoint(x: rect.minX + 6, y: rect.maxY),
                control2: CGPoint(x: rect.minX - 5, y: rect.maxY - 5)
            )
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - 10),
                control1: CGPoint(x: rect.minX - 4, y: rect.maxY - 3),
                control2: CGPoint(x: rect.minX, y: rect.maxY - 3)
            )
        } else {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY - bottomLeading), radius: bottomLeading, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeading))
        path.addArc(center: CGPoint(x: rect.minX + topLeading, y: rect.minY + topLeading), radius: topLeading, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
