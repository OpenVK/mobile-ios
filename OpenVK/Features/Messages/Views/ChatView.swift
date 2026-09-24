import SwiftUI
import Lottie

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ChatViewModel
    @State private var text = ""
    @State private var composerHeight: CGFloat = 40
    @State private var isEmojiPanelPresented = false
    @State private var recentStickers: [VKSticker] = []
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
                messageHistory(viewportHeight: geometry.size.height)
                .overlay(alignment: .bottom) {
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                if conversation.isChat {
                    chatTitle
                } else {
                    NavigationLink {
                        ProfileView(user: conversation.peer)
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
        .alert("Не удалось загрузить сообщения", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("ОК", role: .cancel) {}
        } message: { Text(viewModel.errorMessage ?? "Попробуйте ещё раз") }
    }

    private var chatTitle: some View {
        HStack(spacing: 8) {
            Avatar(user: conversation.peer, size: 28)
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
                        .frame(height: composerContentInset)
                        .id("chat-bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .coordinateSpace(name: "chat-history")
            .overlay(alignment: .bottom) {
                if conversation.isChat, let typing = viewModel.typingText {
                    Text(typing + "…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }
            }
            .onPreferenceChange(ChatMessageFramePreferenceKey.self) { frames in
                let visibleMessage = frames
                    .filter { $0.value.maxY > 0 && $0.value.minY < viewportHeight }
                    .min { $0.value.minY < $1.value.minY }
                if let messageID = visibleMessage?.key {
                    viewModel.rememberPosition(messageID: messageID)
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

    private var composerContentInset: CGFloat {
        if #available(iOS 26.0, *) {
            composerHeight + 16
        } else {
            1
        }
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
            if isPresented { viewModel.loadStickerPacks() }
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
                    viewModel.send(text: value)
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

    var body: some View {
        Group {
            if let systemEventText = message.systemEventText {
                SystemMessagePlaque(text: systemEventText, date: message.date)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    if message.isOutgoing { Spacer(minLength: 48) }
                    if !message.isOutgoing && isChat && !isStickerMessage {
                        if showsSenderDetails {
                            NavigationLink {
                                ProfileView(user: sender)
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
    }

    @ViewBuilder
    private var messageContent: some View {
        if let stickerURL = message.stickerURL {
            sticker(url: stickerURL, animationURL: message.stickerAnimationURL)
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
                NavigationLink {
                    ProfileView(user: sender)
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
