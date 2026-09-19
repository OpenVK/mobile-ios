//
//  MessagesView.swift
//  OpenVK for iOS
//

import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @State private var showCreateChat = false
    @State private var isViewingChat = false

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
            } else if [0, 5, 13, 14, 51, 52].contains(type) {
                viewModel.load()
                AuthService.shared.fetchCounters()
            } else if type == 80 {
                AuthService.shared.fetchCounters()
            }
        }
        .alert(
            "Не удалось загрузить диалоги",
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
            ProgressView("Загрузка диалогов…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.conversations.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 42))
                    .foregroundColor(.secondary)
                Text("Нет диалогов")
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
                        ChatView(conversation: conversation)
                            .onAppear { isViewingChat = true }
                            .onDisappear { isViewingChat = false }
                    } label: {
                        ConversationRow(
                            conversation: conversation,
                            typingText: viewModel.typingText(for: conversation)
                        )
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
