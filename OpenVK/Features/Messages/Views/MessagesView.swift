//
//  MessagesView.swift
//  OpenVK for iOS
//

import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @ObservedObject private var longPoll = LongPollService.shared
    @AppStorage("openvk.ipad.split_chats") private var splitChats = false
    @State private var selectedConversation: Conversation?
    @State private var tabletShowingArchive = false
    @State private var showCreateChat = false
    @State private var showsArchive = false
    @State private var showsArchiveTip = false
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
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad && splitChats {
                // Do not embed the 30:70 layout in the outer navigation stack.
                // It otherwise adds a second title/search toolbar across both
                // columns and pushes the conversation far below its own header.
                tabletSplitContent
            } else {
                MessagesNavigationContainer {
                    archiveNavigableContent
                        .navigationTitle(toolbarTitle)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                if viewModel.hasArchivedConversations {
                                    Button { showsArchive = true } label: {
                                        Image(systemName: "archivebox")
                                    }
                                    .accessibilityLabel("Архив чатов")
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button { showCreateChat = true } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .accessibilityLabel("Написать сообщение")
                            }
                        }
                        .searchable(
                            text: Binding(
                                get: { viewModel.searchQuery },
                                set: { viewModel.updateSearch(query: $0) }
                            ),
                            prompt: "Поиск чатов"
                        )
                }
            }
        }
                .sheet(isPresented: $showCreateChat) {
                    CreateChatView()
                }
                .alert("Чат добавлен в архив", isPresented: $showsArchiveTip) {
                    Button("Понятно", role: .cancel) {}
                } message: {
                    Text("Чтобы открыть архив, нажмите кнопку архива в верхней части списка сообщений. Вернуться можно кнопкой «Назад» или свайпом от левого края экрана.")
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
                            if selectedConversation?.id == conversation.id { selectedConversation = nil }
                            conversationToLeave = nil
                        }
                        Button("Выйти и удалить чат", role: .destructive) {
                            viewModel.leaveChat(conversation, deleteChat: true)
                            if selectedConversation?.id == conversation.id { selectedConversation = nil }
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
                            if selectedConversation?.id == conversation.id {
                                selectedConversation = nil
                            }
                        }
                        conversationToDelete = nil
                    }
                    Button("Отмена", role: .cancel) {
                        conversationToDelete = nil
                    }
                } message: {
                    Text("Чат будет удалён из списка сообщений.")
                }
        .onAppear {
            if viewModel.conversations.isEmpty {
                viewModel.load()
            }
            showFirstArchiveTipIfNeeded()
        }
        .onChange(of: longPoll.connectionState) { state in
            if state == .connected {
                viewModel.load()
                if !viewModel.searchQuery.isEmpty { viewModel.updateSearch(query: viewModel.searchQuery) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ChatArchiveStore.didChange)) { _ in
            viewModel.refreshArchive()
            if let selectedConversation,
               ChatArchiveStore.contains(selectedConversation.id) {
                self.selectedConversation = nil
            }
        }
        .onChange(of: splitChats) { enabled in
            if !enabled {
                selectedConversation = nil
                tabletShowingArchive = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openvkConversationUnreadCountDidChange)) {
            viewModel.updateUnreadCount($0)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openvkLongPollDidReceiveEvent)) { notification in
            let type = notification.userInfo?["type"] as? Int ?? -1
            if type == 4 {
                viewModel.load()
                AuthService.shared.fetchCounters()
            } else if (61...64).contains(type) {
                viewModel.handleLongPollEvent(notification)
            } else if [0, 1, 2, 3, 5, 6, 7, 10, 11, 12, 13, 14, 51, 52].contains(type) {
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

    private var toolbarTitle: String {
        if !longPoll.hasNetworkConnection || longPoll.connectionState == .offline || longPoll.connectionState == .stopped {
            return "Подключение…"
        }
        return longPoll.connectionState.title
    }

    private var archivedChats: some View {
        List {
            ForEach(viewModel.archivedConversations) { conversation in
                NavigationLink {
                    ChatView(
                        conversation: conversation,
                        selectedMedia: $selectedMedia,
                        owningPost: $owningPost
                    )
                } label: {
                    ConversationRow(conversation: conversation, typingText: viewModel.typingText(for: conversation))
                }
                .contextMenu {
                    Button {
                        viewModel.archive(conversation, archived: false)
                    } label: {
                        Label("Вернуть из архива", systemImage: "tray.and.arrow.up")
                    }
                    if conversation.unreadCount > 0 {
                        Button {
                            viewModel.markConversationAsRead(conversation)
                        } label: {
                            Label("Пометить как прочитанное", systemImage: "envelope.open")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.isLoadingArchive && viewModel.archivedConversations.isEmpty {
                ProgressView("Загрузка архива…")
            } else if viewModel.archivedConversations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary)
                    Text("Архив пуст")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Переместите сюда чаты через меню беседы.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            viewModel.refreshArchive()
        }
        .navigationTitle("Архив")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var archiveNavigableContent: some View {
        if #available(iOS 16.0, *) {
            mainMessageContent.navigationDestination(isPresented: $showsArchive) {
                archivedChats
            }
        } else {
            mainMessageContent.background(
                NavigationLink(destination: archivedChats, isActive: $showsArchive) {
                    EmptyView()
                }
                .hidden()
            )
        }
    }

    @ViewBuilder
    private var mainMessageContent: some View {
        if UIDevice.current.userInterfaceIdiom == .pad && splitChats {
            tabletSplitContent
        } else {
            content
        }
    }

    private var tabletSplitContent: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                tabletConversationList
                    .frame(width: geometry.size.width * 0.30, height: geometry.size.height)
                Divider()

                Group {
                    if let conversation = selectedConversation {
                        NavigationView {
                            ChatView(
                                conversation: conversation,
                                selectedMedia: $selectedMedia,
                                owningPost: $owningPost
                            )
                        }
                        .navigationViewStyle(StackNavigationViewStyle())
                        .id(conversation.id)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 38))
                                .foregroundStyle(.secondary)
                            Text("Выберите диалог")
                                .font(.title3.weight(.semibold))
                            Text("Сообщения откроются справа от списка чатов.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var tabletConversationList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if tabletShowingArchive {
                    Button { tabletShowingArchive = false } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Вернуться к сообщениям")
                }
                Text(tabletShowingArchive ? "Архив" : "Сообщения")
                    .font(.headline)
                Spacer(minLength: 0)
                if !tabletShowingArchive {
                    if viewModel.hasArchivedConversations {
                        Button {
                            tabletShowingArchive = true
                            viewModel.refreshArchive()
                        } label: {
                            Image(systemName: "archivebox")
                        }
                        .accessibilityLabel("Архив чатов")
                    }
                    Button { showCreateChat = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Написать сообщение")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)

            if tabletShowingArchive {
                tabletArchivedConversations
            } else {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        "Поиск чатов",
                        text: Binding(
                            get: { viewModel.searchQuery },
                            set: { viewModel.updateSearch(query: $0) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .disableAutocorrection(true)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                content
            }
        }
        .background(Color(.systemBackground))
    }

    private var tabletArchivedConversations: some View {
        List {
            ForEach(viewModel.archivedConversations) { conversation in
                Button {
                    selectedConversation = conversation
                } label: {
                    ConversationRow(conversation: conversation,
                                    typingText: viewModel.typingText(for: conversation))
                }
                .buttonStyle(.plain)
                .listRowBackground(selectedConversation?.id == conversation.id
                    ? Color.appAccent.opacity(0.12) : Color.clear)
                .contextMenu {
                    Button {
                        viewModel.archive(conversation, archived: false)
                        if selectedConversation?.id == conversation.id {
                            selectedConversation = nil
                        }
                    } label: {
                        Label("Вернуть из архива", systemImage: "tray.and.arrow.up")
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.archivedConversations.isEmpty {
                Text("Архив пуст")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
    }

    private func showFirstArchiveTipIfNeeded() {
        if ChatArchiveStore.takePendingFirstArchiveTip() {
            showsArchiveTip = true
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching && !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.searchResults.isEmpty {
            ProgressView("Поиск…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isLoading && viewModel.conversations.isEmpty {
            ProgressView("Загрузка чатов…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.displayedConversations) { conversation in
                    Group {
                        if UIDevice.current.userInterfaceIdiom == .pad && splitChats {
                            Button {
                                selectedConversation = conversation
                            } label: {
                                ConversationRow(
                                    conversation: conversation,
                                    typingText: viewModel.typingText(for: conversation)
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                selectedConversation?.id == conversation.id
                                    ? Color.appAccent.opacity(0.12)
                                    : Color.clear
                            )
                        } else {
                            NavigationLink {
                                ChatView(
                                    conversation: conversation,
                                    selectedMedia: $selectedMedia,
                                    owningPost: $owningPost
                                )
                            } label: {
                                ConversationRow(
                                    conversation: conversation,
                                    typingText: viewModel.typingText(for: conversation)
                                )
                            }
                        }
                    }
                    .contextMenu {
                        Button {
                            viewModel.archive(conversation, archived: true)
                            if selectedConversation?.id == conversation.id {
                                selectedConversation = nil
                            }
                            showFirstArchiveTipIfNeeded()
                        } label: {
                            Label("В архив", systemImage: "archivebox")
                        }

                        if conversation.unreadCount > 0 {
                            Button {
                                viewModel.markConversationAsRead(conversation)
                            } label: {
                                Label("Пометить как прочитанное", systemImage: "envelope.open")
                            }
                        }

                        Button {
                            viewModel.toggleImportant(conversation)
                        } label: {
                            Label(
                                conversation.isImportant ? "Убрать из важных" : "Пометить важным",
                                systemImage: conversation.isImportant ? "star.slash" : "star"
                            )
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
            .overlay {
                if viewModel.displayedConversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: viewModel.searchQuery.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                            .font(.system(size: 42))
                            .foregroundColor(.secondary)
                        Text(viewModel.searchQuery.isEmpty ? (longPoll.connectionState == .offline ? "Нет сохранённых чатов" : "Нет чатов") : "Ничего не найдено")
                            .font(.system(size: 17, weight: .semibold))
                        Text(viewModel.searchQuery.isEmpty ? (longPoll.connectionState == .offline ? "Открытые переписки будут доступны здесь без интернета." : "Здесь появятся ваши личные сообщения") : "Попробуйте изменить запрос")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
            }
        }
    }
}

private struct MessagesNavigationContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
