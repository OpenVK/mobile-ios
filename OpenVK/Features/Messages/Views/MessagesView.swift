//
//  MessagesView.swift
//  OpenVK for iOS
//

import SwiftUI

struct MessagesView: View {

    @StateObject private var viewModel = MessagesViewModel()
    @State private var showNewChat = false

    var body: some View {
        NavigationView {
            listWithNav
                .navigationBarTitle(L10n.Messages.title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showNewChat = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 17))
                                .foregroundColor(.appAccent)
                        }
                    }
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $showNewChat) {
            NewChatView()
                .accentColor(Color.appAccent)
                .tint(Color.appAccent)
        }
        .onAppear {
            if viewModel.conversations.isEmpty {
                viewModel.load()
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundColor(Color(.tertiaryLabel))
            Text(L10n.Messages.empty)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .padding(.top, 10)
            Spacer()
        }
    }

    private var listWithNav: some View {
        Group {
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                VStack {
                    Spacer()
                    LongLoadingIndicator(message: "Насколько сильно любите диалоги в опенвк? Я очень... :)", timeout: 5.0)
                    Spacer()
                }
            } else if viewModel.conversations.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.conversations) { convo in
                    NavigationLink(destination: ChatView(conversation: convo)) {
                        ConversationRow(conversation: convo)
                    }
                    .buttonStyle(PlainButtonStyle())
                    SectionSeparator()
                }

                if viewModel.hasMore {
                    Button(action: { viewModel.loadMore() }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoadingMore {
                                ProgressView()
                            } else {
                                Text("Загрузить ещё")
                                    .font(.system(size: 14))
                                    .foregroundColor(.appAccent)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .refreshable {
            AuthService.shared.fetchCounters()
            viewModel.load()
        }
    }
}

struct NewChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var searchQuery = ""
    @State private var friends: [User] = []
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMore = true
    @State private var isLoadingMore = false
    @State private var lastTriggeredID: UUID? = nil

    var filteredFriends: [User] {
        if searchQuery.isEmpty {
            return friends
        } else {
            return friends.filter { $0.displayName.localizedCaseInsensitiveContains(searchQuery) || $0.username.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    LongLoadingIndicator(message: "Насколько сильно любите диалоги в опенвк? Я очень... :)", timeout: 5.0)
                } else {
                    List {
                        if !filteredFriends.isEmpty {
                            Section(header: Text("Друзья")) {
                                ForEach(filteredFriends) { user in
                                    NavigationLink(destination: ChatView(conversation: Conversation(peer: user, lastMessage: ""))) {
                                        HStack(spacing: 12) {
                                            Avatar(user: user, size: 36)
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Text(user.displayName)
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    
                                                    if user.isOfficial == true {
                                                        Image(systemName: "checkmark.seal.fill")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.appAccent)
                                                    }
                                                    SupporterBadgeView(screenName: user.username)
                                                }
                                                Text("@\(user.username)")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                        .onAppear {
                                            if user.id == filteredFriends.last?.id {
                                                loadMoreFriends()
                                            }
                                        }
                                    }
                                }

                                if isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }

                        if filteredFriends.isEmpty && !isLoading {
                            VStack(spacing: 8) {
                                Spacer()
                                Image(systemName: "person.fill.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(.tertiaryLabel))
                                Text("Ничего не найдено")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitle("Новый чат", displayMode: .inline)
            .navigationBarItems(leading: Button("Закрыть") {
                presentationMode.wrappedValue.dismiss()
            })
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск...")
            .onAppear { loadFriends() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func loadFriends() {
        isLoading = true
        offset = 0
        hasMore = true
        lastTriggeredID = nil
        APIClient.shared.call(
            method: "friends.get",
            parameters: [
                "fields": "photo_100,online,last_seen",
                "count": "30",
                "offset": "0"
            ],
            httpMethod: "GET",
            as: VKSearchResponseInner<VKUserProfile>.self
        ) { result in
            isLoading = false
            switch result {
            case .success(let inner):
                let mapped = (inner.items ?? []).map { vkUser -> User in
                    let name = "\(vkUser.firstName ?? "") \(vkUser.lastName ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
                    return User(
                        uid: vkUser.id,
                        username: vkUser.screenName ?? "id\(vkUser.id)",
                        displayName: name.isEmpty ? "Пользователь" : name,
                        avatarURL: (vkUser.photo100).flatMap { URL(string: $0) },
                        isOnline: vkUser.online == 1,
                        onlinePlatform: vkUser.lastSeen?.platformName
                    )
                }
                friends = mapped
                offset = 1
                hasMore = mapped.count >= 30
            case .failure:
                break
            }
        }
    }

    private func loadMoreFriends() {
        guard !isLoading, !isLoadingMore, hasMore else { return }
        
        if let lastID = filteredFriends.last?.id {
            if lastTriggeredID == lastID {
                return
            }
            lastTriggeredID = lastID
        }
        
        isLoadingMore = true
        APIClient.shared.call(
            method: "friends.get",
            parameters: [
                "fields": "photo_100,online,last_seen",
                "count": "30",
                "offset": "\(offset)"
            ],
            httpMethod: "GET",
            as: VKSearchResponseInner<VKUserProfile>.self
        ) { result in
            isLoadingMore = false
            switch result {
            case .success(let inner):
                let mapped = (inner.items ?? []).map { vkUser -> User in
                    let name = "\(vkUser.firstName ?? "") \(vkUser.lastName ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
                    return User(
                        uid: vkUser.id,
                        username: vkUser.screenName ?? "id\(vkUser.id)",
                        displayName: name.isEmpty ? "Пользователь" : name,
                        avatarURL: (vkUser.photo100).flatMap { URL(string: $0) },
                        isOnline: vkUser.online == 1,
                        onlinePlatform: vkUser.lastSeen?.platformName
                    )
                }
                if mapped.isEmpty {
                    hasMore = false
                } else {
                    friends.append(contentsOf: mapped)
                    offset += 1
                    hasMore = mapped.count >= 30
                }
            case .failure:
                break
            }
        }
    }
}

struct LongLoadingIndicator: View {
    var message: String = "Насколько сильно любите диалоги в опенвк? Я очень... :)"
    var timeout: TimeInterval = 5.0

    @State private var showMessage = false

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            if showMessage {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .onAppear {
            showMessage = false
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                withAnimation {
                    showMessage = true
                }
            }
        }
    }
}
