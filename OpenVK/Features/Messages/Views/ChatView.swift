import SwiftUI
import Lottie

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ChatViewModel
    @State private var text = ""
    @State private var composerHeight: CGFloat = 40
    @State private var isEmojiPanelPresented = false
    @State private var recentStickers: [VKSticker] = []
    @State private var selectedVideo: ChatVideo?
    @State private var profileToShow: User?
    @State private var replyToMessage: ChatMessage?
    @State private var editingMessage: ChatMessage?
    @State private var messageToDelete: ChatMessage?
    @FocusState private var isComposerFocused: Bool
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(
        conversation: Conversation,
        selectedMedia: Binding<Attachment?> = .constant(nil),
        owningPost: Binding<Post?> = .constant(nil)
    ) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
        _selectedMedia = selectedMedia
        _owningPost = owningPost
    }

    var body: some View {
        GeometryReader { geometry in
                messageHistory(viewportHeight: max(0, geometry.size.height - composerHeight))
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if #available(iOS 26.0, *) {
                        if viewModel.canSendMessages {
                            messageComposer(maxHeight: geometry.size.height / 2)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                                .background(
                                    GeometryReader { composerGeometry in
                                        Color.clear.preference(
                                            key: ComposerHeightPreferenceKey.self,
                                            value: composerGeometry.size.height
                                        )
                                    }
                                )
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
                }
        }
        .background(Color.white)
        .onPreferenceChange(ComposerHeightPreferenceKey.self) { composerHeight = $0 }
        .onChange(of: text) { viewModel.sendTyping(for: $0) }
        .navigationBarTitleDisplayMode(.inline)
        .chatTabBarHidden()
        .toolbar {
            ToolbarItem(placement: .principal) {
                if conversation.isChat {
                    chatTitle
                } else {
                    Button {
                        profileToShow = conversation.peer
                    } label: {
                        chatTitle
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            viewModel.load()
            viewModel.startListening()
        }
        .background(profileNavigationLink)
        .alert("Не удалось загрузить сообщения", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("ОК", role: .cancel) {}
        } message: { Text(viewModel.errorMessage ?? "Попробуйте ещё раз") }
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

    private var chatTitle: some View {
        HStack(spacing: 8) {
            Avatar(
                user: conversation.peer,
                size: 28,
                placeholderImageName: conversation.isChat ? "chat_default_100" : nil
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

    private func memberCountWord(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "участников" }
        if last == 1 { return "участник" }
        if (2...4).contains(last) { return "участника" }
        return "участников"
    }

    private func messageHistory(viewportHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if viewModel.isLoadingOlder { ProgressView().padding(8) }
                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(
                            message: message,
                            isChat: conversation.isChat,
                            showsSenderDetails: shouldShowSenderDetails(for: index),
                            joinsPrevious: joinsMessage(at: index, with: index - 1),
                            joinsNext: joinsMessage(at: index, with: index + 1)
                        ) { photo in
                            openPhotoViewer(for: photo)
                        } onVideoTap: { video in
                            selectedVideo = video
                        } onProfileTap: { user in
                            profileToShow = user
                        } onReply: { message in
                            replyToMessage = message
                            editingMessage = nil
                            isComposerFocused = true
                        } onEdit: { message in
                            editingMessage = message
                            replyToMessage = nil
                            text = message.text
                            isComposerFocused = true
                        } onDelete: { message in
                            messageToDelete = message
                        }
                            .id(message.id)
                            .onAppear { viewModel.loadOlderIfNeeded(message: message) }
                            .background(
                                GeometryReader { messageGeometry in
                                    Color.clear.preference(
                                        key: ChatMessageFramePreferenceKey.self,
                                        value: [message.id: messageGeometry.frame(in: .named("chat-history"))]
                                    )
                                }
                            )
                    }
                    if viewModel.isLoading && viewModel.messages.isEmpty { ProgressView().padding(.top, 30) }
                    Color.clear
                        .frame(height: 1)
                        .id("chat-bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .coordinateSpace(name: "chat-history")
            .onPreferenceChange(ChatMessageFramePreferenceKey.self) { frames in
                let visibleMessage = frames
                    .filter { $0.value.maxY > 0 && $0.value.minY < viewportHeight }
                    .min { $0.value.minY < $1.value.minY }
                if let messageID = visibleMessage?.key {
                    viewModel.rememberPosition(messageID: messageID)
                }
                if let lastMessageID = viewModel.messages.last?.id,
                   let lastFrame = frames[lastMessageID] {
                    viewModel.updateIsNearBottom(lastFrame.maxY <= viewportHeight + 32)
                } else if !viewModel.messages.isEmpty {
                    viewModel.updateIsNearBottom(false)
                }
            }
            .onChange(of: viewModel.scrollRequestID) { _ in
                Task { @MainActor in
                    await Task.yield()
                    await Task.yield()
                    switch viewModel.scrollRequest {
                    case .initial(let savedMessageID):
                        if let savedMessageID,
                           viewModel.messages.contains(where: { $0.id == savedMessageID }) {
                            proxy.scrollTo(savedMessageID, anchor: .top)
                        } else {
                            proxy.scrollTo("chat-bottom", anchor: .bottom)
                        }
                    case .preservePosition(let messageID):
                        proxy.scrollTo(messageID, anchor: .top)
                    case .bottom(let animated):
                        if animated {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("chat-bottom", anchor: .bottom)
                            }
                        } else {
                            proxy.scrollTo("chat-bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
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
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard isEmojiPanelPresented else { return }
                viewModel.scrollToBottom()
            }
        }
    }

    @available(iOS 26.0, *)
    private func composerControls(maximumLines: Int) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {} label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Добавить вложение")

            TextField("Сообщение", text: $text, axis: .vertical)
                .font(.body)
                .lineLimit(1...maximumLines)
                .focused($isComposerFocused)
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
                            .frame(width: 40, height: 40)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    .accessibilityLabel("Эмодзи")
                }

            if hasMessageText {
                Button {
                    let value = text
                    text = ""
                    if let editingMessage {
                        viewModel.edit(message: editingMessage, text: value)
                        self.editingMessage = nil
                    } else {
                        viewModel.send(text: value, replyTo: replyToMessage?.id)
                        replyToMessage = nil
                    }
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
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: hasMessageText)
    }

    private var hasMessageText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @available(iOS 26.0, *)
    private func messageActionBanner(title: String, subtitle: String, cancel: @escaping () -> Void) -> some View {
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sendSticker(_ sticker: VKSticker) {
        viewModel.send(sticker: sticker)
        recentStickers.removeAll { $0.identifier == sticker.identifier }
        recentStickers.insert(sticker, at: 0)
        recentStickers = Array(recentStickers.prefix(32))
    }

    private func openPhotoViewer(for photo: ChatPhoto) {
        let photos = viewModel.messages.flatMap(\.photos)
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

}

private struct ChatMessageFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

@available(iOS 26.0, *)
private struct StickerPickerPanel: View {
    let packs: [VKStickerPack]
    let recentStickers: [VKSticker]
    let isLoading: Bool
    let onStickerSelected: (VKSticker) -> Void

    private let grid = [GridItem(.adaptive(minimum: 62), spacing: 6)]

    var body: some View {
        VStack(spacing: 0) {
            packTabs
            Divider()
            content
        }
        .background(Color(.secondarySystemBackground).opacity(0.35), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var packTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !recentStickers.isEmpty {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 38, height: 38)
                        .background(Color.appAccent.opacity(0.12), in: Circle())
                }
                ForEach(packs) { pack in
                    stickerImage(url: pack.coverURL)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .accessibilityLabel(pack.displayName)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .frame(height: 52)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && packs.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if packs.isEmpty {
            ContentUnavailableView("Нет стикерпаков", systemImage: "face.smiling", description: Text("Установленные стикерпаки появятся здесь."))
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !recentStickers.isEmpty { stickerSection(title: "Недавние", stickers: recentStickers) }
                    ForEach(packs) { pack in
                        stickerSection(title: pack.displayName, stickers: pack.stickers ?? [])
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
                        stickerImage(url: sticker.thumbnailURL).frame(width: 62, height: 62)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

private extension View {
    @ViewBuilder func chatTabBarHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .tabBar)
        } else {
            self
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

private struct ComposerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 40

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isChat: Bool
    let showsSenderDetails: Bool
    let joinsPrevious: Bool
    let joinsNext: Bool
    let onPhotoTap: (ChatPhoto) -> Void
    let onVideoTap: (ChatVideo) -> Void
    let onProfileTap: (User) -> Void
    let onReply: (ChatMessage) -> Void
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
                    if !message.isOutgoing && isChat && !isStickerMessage {
                        if showsSenderDetails {
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
        } else if let video = message.videos.first {
            videoBubble(video)
        } else if !message.photos.isEmpty {
            photoBubble
        } else {
            bubble
        }
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

            messageTextAndMetadata
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
                bottomTrailingRadius: message.isOutgoing && joinsNext ? 8 : 18
            )
        )
    }

    private var messageText: some View {
        Text(message.isDeleted ? "Сообщение удалено" : message.text)
            .font(.system(size: 16))
            .foregroundStyle(message.isOutgoing ? .white : (message.isDeleted ? .secondary : .primary))
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
            .padding(.trailing, metadataSlotWidth)
            .padding(.bottom, 14)
            .overlay(alignment: .bottomTrailing) {
                messageMetadata.frame(width: metadataSlotWidth, alignment: .trailing)
            }
    }

    private var metadataSlotWidth: CGFloat { 50 }

    private var timeLabel: some View {
        Text(message.date, style: .time)
            .font(.system(size: 10))
            .foregroundStyle(message.isOutgoing ? .white.opacity(0.75) : .secondary)
    }

    private var messageMetadata: some View {
        HStack(spacing: 4) {
            timeLabel
            if let status = message.deliveryStatus {
                deliveryStatusLabel(status)
            }
        }
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
        return min(UIScreen.main.bounds.width - reservedWidth, 300)
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
                    CachedRemoteImage(url: photo.url, contentMode: .fill) {
                        Color(.secondarySystemBackground)
                            .overlay { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: tileHeight)
                    .clipped()
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: width)
    }

    private var tileHeight: CGFloat {
        if visiblePhotos.count == 1 { return 260 }
        return visiblePhotos.count <= 4 ? 150 : 100
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
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: Capsule())
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

private struct MessageBubbleShape: Shape {
    let topLeadingRadius: CGFloat
    let topTrailingRadius: CGFloat
    let bottomLeadingRadius: CGFloat
    let bottomTrailingRadius: CGFloat

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
        path.addArc(center: CGPoint(x: rect.maxX - bottomTrailing, y: rect.maxY - bottomTrailing), radius: bottomTrailing, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY - bottomLeading), radius: bottomLeading, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeading))
        path.addArc(center: CGPoint(x: rect.minX + topLeading, y: rect.minY + topLeading), radius: topLeading, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
