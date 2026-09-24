//
//  MessagesView.swift
//  OpenVK for iOS
//

import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @State private var showCreateChat = false
    @State private var isViewingChat = false
    @State private var conversationToDelete: Conversation?
    @State private var conversationToLeave: Conversation?
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(
        selectedMedia: Binding<Attachment?> = .constant(nil),
        owningPost: Binding<Post?> = .constant(nil)
    ) {
        _selectedMedia = selectedMedia
        _owningPost = owningPost
    }

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Сообщения")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showCreateChat = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .accessibilityLabel("Написать сообщение")
                    }
                }
                .sheet(isPresented: $showCreateChat) {
                    CreateChatView()
                }
                .confirmationDialog(
                    "Выйти из беседы?",
                    isPresented: Binding(
                        get: { conversationToLeave != nil },
                        set: { if !$0 { conversationToLeave = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    if let conversation = conversationToLeave {
                        Button("Выйти") {
                            viewModel.leaveChat(conversation, deleteChat: false)
                            conversationToLeave = nil
                        }
                        Button("Выйти и удалить чат", role: .destructive) {
                            viewModel.leaveChat(conversation, deleteChat: true)
                            conversationToLeave = nil
                        }
                    }
                    Button("Отмена", role: .cancel) {
                        conversationToLeave = nil
                    }
                } message: {
                    if let conversation = conversationToLeave {
                        Text("Вы покинете «\(conversation.peer.displayName)».")
                    }
                }
                .confirmationDialog(
                    "Удалить чат?",
                    isPresented: Binding(
                        get: { conversationToDelete != nil },
                        set: { if !$0 { conversationToDelete = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Удалить", role: .destructive) {
                        if let conversation = conversationToDelete {
                            viewModel.deleteConversation(conversation)
                        }
                        conversationToDelete = nil
                    }
                    Button("Отмена", role: .cancel) {
                        conversationToDelete = nil
                    }
                } message: {
                    Text("Чат будет удалён из списка сообщений.")
                }
        }
        .chatTabBarVisibility(isHidden: isViewingChat)
        .onAppear {
            if viewModel.conversations.isEmpty {
                viewModel.load()
            }
        }
        .refreshable {
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openvkLongPollDidReceiveEvent)) { notification in
            let type = notification.userInfo?["type"] as? Int ?? -1
            if type == 4 {
                viewModel.load()
                AuthService.shared.fetchCounters()
            } else if (61...64).contains(type) {
                viewModel.handleLongPollEvent(notification)
            } else if [0, 3, 5, 7, 13, 14, 51, 52].contains(type) {
                viewModel.load()
                AuthService.shared.fetchCounters()
            } else if type == 80 {
                AuthService.shared.fetchCounters()
            }
        }
        .alert(
            "Не удалось выполнить запрос",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Попробуйте ещё раз")
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.conversations.isEmpty {
            ProgressView("Загрузка чатов…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.conversations.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 42))
                    .foregroundColor(.secondary)
                Text("Нет чатов")
                    .font(.system(size: 17, weight: .semibold))
                Text("Здесь появятся ваши личные сообщения")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink {
                        ChatView(
                            conversation: conversation,
                            selectedMedia: $selectedMedia,
                            owningPost: $owningPost
                        )
                            .onAppear { isViewingChat = true }
                            .onDisappear { isViewingChat = false }
                    } label: {
                        ConversationRow(
                            conversation: conversation,
                            typingText: viewModel.typingText(for: conversation)
                        )
                    }
                    .contextMenu {
                        if conversation.unreadCount > 0 {
                            Button {
                                viewModel.markConversationAsRead(conversation)
                            } label: {
                                Label("Пометить как прочитанное", systemImage: "envelope.open")
                            }
                        }

                        if conversation.isChat && conversation.isChatMember {
                            Button(role: .destructive) {
                                conversationToLeave = conversation
                            } label: {
                                Label {
                                    Text("Выйти из беседы")
                                } icon: {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .symbolRenderingMode(.monochrome)
                                        .foregroundStyle(.red)
                                }
                            }
                            .tint(.red)
                        } else if conversation.isChat {
                            Button(role: .destructive) {
                                conversationToDelete = conversation
                            } label: {
                                Label {
                                    Text("Удалить чат")
                                } icon: {
                                    Image(systemName: "trash")
                                        .symbolRenderingMode(.monochrome)
                                        .foregroundStyle(.red)
                                }
                            }
                            .tint(.red)
                        } else {
                            Button(role: .destructive) {
                                conversationToDelete = conversation
                            } label: {
                                Label {
                                    Text("Удалить чат")
                                } icon: {
                                    Image(systemName: "trash")
                                        .symbolRenderingMode(.monochrome)
                                        .foregroundStyle(.red)
                                }
                            }
                            .tint(.red)
                        }
                    }
                    .contentShape(Rectangle())
                    .onAppear {
                        viewModel.loadMoreIfNeeded(after: conversation)
                    }
                }

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
    }
}

private extension View {
    @ViewBuilder func chatTabBarVisibility(isHidden: Bool) -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(isHidden ? .hidden : .visible, for: .tabBar)
        } else {
            self
        }
    }
}
