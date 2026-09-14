//
//  MessagesView.swift
//  OpenVK for iOS
//

import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @State private var showCreateChat = false

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
        .onAppear {
            if viewModel.conversations.isEmpty {
                viewModel.load()
            }
        }
        .refreshable {
            viewModel.load()
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
                    ConversationRow(conversation: conversation)
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
