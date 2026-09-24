//
//  CreateChatView.swift
//  OpenVK for iOS
//

import SwiftUI

struct CreateChatView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = CreateChatViewModel()
    @State private var query = ""
    @State private var showConversationStub = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoadingFriends {
                    ProgressView("Загрузка друзей…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.friends.isEmpty {
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Повторить") {
                            viewModel.loadFriends()
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    results
                }
            }
            .navigationTitle("Написать сообщение")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Поиск..."
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel("Закрыть")
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            viewModel.loadFriends()
        }
        .onChange(of: query) { newValue in
            viewModel.searchGlobal(query: newValue)
        }
        .sheet(isPresented: $showConversationStub) {
            NavigationView {
                UnderDevelopmentView(section: "Создание беседы")
                    .navigationTitle("Создать беседу")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Готово") {
                                showConversationStub = false
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            friendList
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    createConversationButton
                    resultSection(title: "Друзья", users: viewModel.filteredFriends(for: query))
                    resultSection(title: "Поиск по OpenVK", users: viewModel.globalUsers)

                    if viewModel.isLoadingGlobal {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
        }
    }

    private var friendList: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                List {
                    createConversationButton
                        .listRowInsets(EdgeInsets())

                    ForEach(viewModel.groupedFriends, id: \.0) { letter, group in
                        Section {
                            ForEach(group) {
                                userRow($0)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.visible)
                            }
                        } header: {
                            Text(letter)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.appAccent)
                                .id(letter)
                        }
                    }
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 16)
                }

                alphabetIndex(proxy: proxy)
                    .padding(.trailing, 4)
            }
        }
    }

    private var createConversationButton: some View {
        Button {
            showConversationStub = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.appAccent)
                    .frame(width: 28)
                Text("Создать беседу")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func resultSection(title: String, users: [User]) -> some View {
        Group {
            if !users.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ForEach(users) { user in
                    userRow(user)
                        .onAppear {
                            viewModel.loadMoreGlobalIfNeeded(after: user, query: query)
                        }
                }
            }
        }
    }

    private func userRow(_ user: User) -> some View {
        Button {
            showConversationStub = true
        } label: {
            HStack(spacing: 12) {
                Avatar(user: user, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName == "DELETED" ? "Удалённый аккаунт" : user.displayName)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    if user.deactivated != "deleted" {
                        Text("@\(user.username)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func alphabetIndex(proxy: ScrollViewProxy) -> some View {
        let letters = viewModel.groupedFriends.map(\.0)

        return GeometryReader { geometry in
            let availableHeight = max(0, geometry.size.height - 20)
            let itemHeight = max(
                8,
                min(16, (availableHeight - 10) / CGFloat(max(letters.count, 1)))
            )
            let indexHeight = CGFloat(letters.count) * itemHeight + 10
            let topInset = max(0, (geometry.size.height - indexHeight) / 2)

            VStack(spacing: 0) {
                ForEach(letters, id: \.self) { letter in
                    Button(letter) {
                        scrollToLetter(letter, using: proxy)
                    }
                    .font(.system(size: min(10, itemHeight * 0.7), weight: .semibold))
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.appAccent)
                    .frame(width: 26, height: itemHeight)
                }
            }
            .padding(.vertical, 5)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .frame(width: 32, height: indexHeight)
            .position(x: geometry.size.width - 20, y: topInset + indexHeight / 2)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !letters.isEmpty else { return }
                        let contentY = value.location.y - topInset - 5
                        let index = min(
                            max(Int(contentY / itemHeight), 0),
                            letters.count - 1
                        )
                        scrollToLetter(letters[index], using: proxy)
                    }
            )
        }
        .frame(width: 40)
    }

    private func scrollToLetter(_ letter: String, using proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo(letter, anchor: .top)
        }
    }
}
