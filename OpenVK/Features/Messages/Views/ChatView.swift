import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ChatViewModel

    init(conversation: Conversation) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageHistory
        }
        .background(Color.white)
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
            Text(conversation.peer.displayName)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
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
                        .frame(height: 1)
                        .id("chat-bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .overlay(alignment: .bottom) {
                if let typing = viewModel.typingText {
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
                    timeLabel
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    messageText
                    HStack {
                        Spacer(minLength: 0)
                        timeLabel
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

    private var displaysTimeBesideText: Bool {
        message.text.count <= 25 && !message.isDeleted
    }

    private var sender: User { User(uid: 0, username: "", displayName: message.senderName ?? "", isGroup: false) }
}
