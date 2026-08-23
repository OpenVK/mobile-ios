//
//  CreateChatView.swift
//  OpenVK for iOS
//

import SwiftUI

struct CreateChatView: View {

    @ObservedObject var viewModel: MessagesViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var title = ""
    @State private var searchQuery = ""
    @State private var friends: [User] = []
    @State private var selectedUserIds: Set<Int> = []
    @State private var isLoadingFriends = false
    @State private var isCreating = false
    @State private var errorMessage: String? = nil

    var filteredFriends: [User] {
        if searchQuery.isEmpty {
            return friends
        } else {
            return friends.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
                $0.username.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }

    var selectedFriends: [User] {
        friends.filter { selectedUserIds.contains($0.uid ?? 0) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Название беседы", text: $title)
                        .font(.system(size: 16))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if !selectedFriends.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedFriends) { user in
                                HStack(spacing: 4) {
                                    Avatar(user: user, size: 24)
                                    Text(user.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    Button(action: {
                                        withAnimation {
                                            _ = selectedUserIds.remove(user.uid ?? 0)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.leading, 4)
                                .padding(.trailing, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(.secondarySystemBackground)))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }

                Divider()

                if isLoadingFriends && friends.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    List {
                        Section(header: Text("Пригласить друзей (\(selectedUserIds.count))")) {
                            ForEach(filteredFriends) { user in
                                let uid = user.uid ?? 0
                                let isSelected = selectedUserIds.contains(uid)

                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if isSelected {
                                            _ = selectedUserIds.remove(uid)
                                        } else {
                                            _ = selectedUserIds.insert(uid)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Avatar(user: user, size: 40)

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
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationBarTitle("Создать беседу", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Отмена") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Создать") {
                    createChat()
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            )
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Поиск друзей...")
            .alert(isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Alert(title: Text("Ошибка"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                loadFriends()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func createChat() {
        let chatTitle = title.trimmingCharacters(in: .whitespaces)
        guard !chatTitle.isEmpty else { return }

        isCreating = true
        let ids = Array(selectedUserIds)

        viewModel.createChat(title: chatTitle, userIds: ids) { result in
            isCreating = false
            switch result {
            case .success:
                presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadFriends() {
        isLoadingFriends = true
        APIClient.shared.call(
            method: "friends.get",
            parameters: [
                "fields": "photo_100,online,last_seen",
                "count": "100",
                "offset": "0"
            ],
            httpMethod: "GET",
            as: VKSearchResponseInner<VKUserProfile>.self
        ) { result in
            isLoadingFriends = false
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
            case .failure:
                break
            }
        }
    }
}
