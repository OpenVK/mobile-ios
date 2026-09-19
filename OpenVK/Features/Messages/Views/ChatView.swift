import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ChatViewModel
    @State private var text = ""
    @State private var composerHeight: CGFloat = 40
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
            messageHistory
                .overlay(alignment: .bottom) {
                    if #available(iOS 26.0, *) {
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
                if !conversation.isChat, let typing = viewModel.typingText {
                    TypingStatusView(text: typing)
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

    private var messageHistory: some View {
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
                    }
                    if viewModel.isLoading && viewModel.messages.isEmpty { ProgressView().padding(.top, 30) }
                    Color.clear
                        .frame(height: composerContentInset)
                        .id("chat-bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
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
            .onChange(of: viewModel.messages.count) { count in
                guard count > 0 else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    withAnimation { proxy.scrollTo("chat-bottom", anchor: .bottom) }
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
        return message.senderID == neighbor.senderID && message.isOutgoing == neighbor.isOutgoing
    }

    @available(iOS 26.0, *)
    private func messageComposer(maxHeight: CGFloat) -> some View {
        let maximumLines = max(1, Int((maxHeight - 20) / 22))

        return HStack(alignment: .bottom, spacing: 8) {
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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

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
        HStack(alignment: .bottom, spacing: 6) {
            if message.isOutgoing { Spacer(minLength: 48) }
            if !message.isOutgoing && isChat && !isStickerMessage {
                if showsSenderDetails {
                    Avatar(user: sender, size: 26)
                } else {
                    Color.clear.frame(width: 26, height: 26)
                }
            }
            messageContent
            if !message.isOutgoing { Spacer(minLength: 48) }
        }
        .padding(.top, joinsPrevious ? 0 : 4)
    }

    @ViewBuilder
    private var messageContent: some View {
        if let stickerURL = message.stickerURL {
            sticker(url: stickerURL)
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

    private func sticker(url: URL) -> some View {
        ZStack(alignment: .bottomTrailing) {
            CachedRemoteImage(url: url, contentMode: .fit) {
                ProgressView()
                    .frame(width: 160, height: 160)
            }
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
                Text(senderName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
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
            username: "",
            displayName: message.senderName ?? "",
            avatarURL: message.senderAvatarURL,
            isGroup: false
        )
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
