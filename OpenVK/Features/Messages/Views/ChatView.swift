import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ChatViewModel
    @State private var text = ""
    @State private var composerHeight: CGFloat = 40

    init(conversation: Conversation) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
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
                LazyVStack(spacing: 6) {
                    if viewModel.isLoadingOlder { ProgressView().padding(8) }
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message, isChat: conversation.isChat)
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

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isOutgoing { Spacer(minLength: 48) }
            if !message.isOutgoing && isChat { Avatar(user: sender, size: 26) }
            bubble
            if !message.isOutgoing { Spacer(minLength: 48) }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !message.isOutgoing, let senderName = message.senderName {
                Text(senderName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
            }

            if displaysTimeBesideText {
                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    messageText
                    messageMetadata
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    messageText
                    HStack {
                        Spacer(minLength: 0)
                        messageMetadata
                    }
                }
            }
        }
        .foregroundStyle(message.isOutgoing ? .white : .primary)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(
            message.isOutgoing ? Color.appAccent : Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var messageText: some View {
        Text(message.isDeleted ? "Сообщение удалено" : message.text)
            .font(.system(size: 16))
            .foregroundStyle(message.isOutgoing ? .white : (message.isDeleted ? .secondary : .primary))
    }

    private var timeLabel: some View {
        Text(message.date, style: .time)
            .font(.caption2)
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

    private var displaysTimeBesideText: Bool {
        message.text.count <= (message.isOutgoing ? 18 : 25) && !message.isDeleted
    }

    private var sender: User { User(uid: 0, username: "", displayName: message.senderName ?? "", isGroup: false) }
}
