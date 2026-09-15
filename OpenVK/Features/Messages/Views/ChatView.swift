import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ChatViewModel
    @State private var text = ""
    @FocusState private var focused: Bool

    init(conversation: Conversation) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageHistory
            if #unavailable(iOS 26.0) { inputBar }
        }
        .background(Color(.systemGroupedBackground))
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
        .hideMessagesTabBar()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if #available(iOS 26.0, *) { inputBar.padding(.horizontal, 12).padding(.bottom, 6) }
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
            .onChange(of: viewModel.messages.last?.id) { id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {} label: { Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundStyle(.secondary) }
            TextField("Сообщение", text: $text)
                .focused($focused)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemBackground), in: Capsule())
            Button {
                let value = text
                text = ""
                viewModel.send(text: value)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 29))
                    .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : Color.appAccent)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .ifAvailableGlass()
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isChat: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isOutgoing { Spacer(minLength: 48) }
            if !message.isOutgoing && isChat { Avatar(user: sender, size: 26) }
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 3) {
                if !message.isOutgoing && isChat, let sender = message.senderName { Text(sender).font(.caption2).foregroundStyle(.secondary) }
                Text(message.isDeleted ? "Сообщение удалено" : message.text)
                    .font(.system(size: 16))
                    .foregroundStyle(message.isDeleted ? .secondary : .primary)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(message.isOutgoing ? Color.appAccent : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundColor(message.isOutgoing ? .white : .primary)
                Text(message.date, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            if !message.isOutgoing { Spacer(minLength: 48) }
        }
    }

    private var sender: User { User(uid: 0, username: "", displayName: message.senderName ?? "", isGroup: false) }
}

private extension View {
    @ViewBuilder func ifAvailableGlass() -> some View {
        if #available(iOS 26.0, *) { self.glassEffect(.regular, in: Capsule()) }
        else { self }
    }

    @ViewBuilder func hideMessagesTabBar() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .tabBar)
        } else {
            self
        }
    }
}
