//
//  ChatDetailsView.swift
//  OpenVK for iOS
//

import SwiftUI

struct ChatDetailsView: View {

    let conversation: Conversation
    @Environment(\.presentationMode) var presentationMode

    @State private var members: [ChatMember] = []
    @State private var isLoadingMembers = false
    @State private var showAddMemberSheet = false
    @State private var errorMessage: String? = nil

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Avatar(peer: conversation.peer, size: 74)

                    Text(conversation.peer.title)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text("\(members.count > 0 ? members.count : (conversation.peer.membersCount ?? 1)) участников")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                Button(action: { showAddMemberSheet = true }) {
                    Label("Добавить участников", systemImage: "person.badge.plus")
                        .foregroundColor(.appAccent)
                }
            }

            Section(header: Text("Участники беседы")) {
                if isLoadingMembers && members.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            if let u = member.user {
                                NavigationLink(destination: ProfileView(user: u)) {
                                    memberRowContent(member)
                                }
                            } else {
                                memberRowContent(member)
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if member.canKick {
                                Button(role: .destructive) {
                                    kickMember(member.userId)
                                } label: {
                                    Label("Исключить", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive, action: { leaveChat() }) {
                    HStack {
                        Spacer()
                        Text("Покинуть беседу")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitle("Информация", displayMode: .inline)
        .sheet(isPresented: $showAddMemberSheet) {
            AddChatMemberView(peerId: conversation.peer.id) {
                loadMembers()
            }
            .accentColor(Color.appAccent)
        }
        .alert(isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Alert(title: Text("Ошибка"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            loadMembers()
        }
    }

    private func memberRowContent(_ member: ChatMember) -> some View {
        HStack(spacing: 12) {
            if let user = member.user {
                Avatar(user: user, size: 40)
            } else {
                Avatar(url: nil, placeholderSystemName: "person.fill", size: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.user?.displayName ?? "Пользователь \(member.userId)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                if member.isAdmin {
                    Text("Администратор")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appAccent)
                } else if let user = member.user {
                    Text("@\(user.username)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    private func loadMembers() {
        isLoadingMembers = true
        MessagesService.shared.fetchChatMembers(peerID: conversation.peer.id, groupId: nil) { result in
            DispatchQueue.main.async {
                isLoadingMembers = false
                switch result {
                case .success(let items):
                    members = items
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func kickMember(_ userId: Int) {
        MessagesService.shared.removeChatUser(peerID: conversation.peer.id, userId: userId, groupId: nil) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    members.removeAll { $0.userId == userId }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func leaveChat() {
        MessagesService.shared.removeChatUser(peerID: conversation.peer.id, userId: 0, groupId: nil) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct AddChatMemberView: View {
    let peerId: Int
    var onAdded: () -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var searchQuery = ""
    @State private var friends: [User] = []
    @State private var selectedUserIds: Set<Int> = []
    @State private var isLoading = false
    @State private var isAdding = false

    var filteredFriends: [User] {
        if searchQuery.isEmpty {
            return friends
        } else {
            return friends.filter { $0.displayName.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredFriends) { user in
                    let uid = user.uid ?? 0
                    let isSelected = selectedUserIds.contains(uid)

                    Button(action: {
                        if isSelected {
                            selectedUserIds.remove(uid)
                        } else {
                            selectedUserIds.insert(uid)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Avatar(user: user, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("@\(user.username)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .appAccent : Color(.systemGray4))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Добавить участников", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Отмена") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Добавить") {
                    addSelected()
                }
                .disabled(selectedUserIds.isEmpty || isAdding)
            )
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск друзей...")
            .onAppear { loadFriends() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func loadFriends() {
        isLoading = true
        APIClient.shared.call(
            method: "friends.get",
            parameters: ["fields": "photo_100,online", "count": "100"],
            httpMethod: "GET",
            as: VKSearchResponseInner<VKUserProfile>.self
        ) { result in
            isLoading = false
            if case .success(let inner) = result {
                friends = (inner.items ?? []).map {
                    let name = "\($0.firstName ?? "") \($0.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                    return User(
                        uid: $0.id,
                        username: $0.screenName ?? "id\($0.id)",
                        displayName: name.isEmpty ? "Пользователь" : name,
                        avatarURL: $0.photo100.flatMap { URL(string: $0) },
                        isOnline: $0.online == 1
                    )
                }
            }
        }
    }

    private func addSelected() {
        isAdding = true
        let ids = Array(selectedUserIds)
        MessagesService.shared.addChatUser(peerID: peerId, userIds: ids, groupId: nil) { result in
            DispatchQueue.main.async {
                isAdding = false
                if case .success = result {
                    onAdded()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
