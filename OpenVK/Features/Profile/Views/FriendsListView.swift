//
//  FriendsListView.swift
//  OpenVK for iOS
//
//  Экран списка друзей.
//

import SwiftUI

enum FriendSortOrder: String, CaseIterable {
    case online = "По активности"
    case alphabet = "По алфавиту"
}

struct FriendsListView: View {

    let ownerID: Int
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?
    @State private var friends: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    init(ownerID: Int, selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        self.ownerID = ownerID
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }
    
    @State private var sortOrder: FriendSortOrder = .online
    @State private var searchQuery = ""
    @State private var dragSelectedLetter: String? = nil

    private var filteredFriends: [User] {
        if searchQuery.isEmpty {
            return friends
        }
        return friends.filter { $0.displayName.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var sortedFriends: [User] {
        switch sortOrder {
        case .online:
            return filteredFriends.sorted { $0.isOnline && !$1.isOnline }
        case .alphabet:
            return filteredFriends.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }
    }

    private var groupedByLetter: [(String, [User])] {
        let grouped = Dictionary(grouping: sortedFriends) { user -> String in
            guard let firstChar = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines).first else {
                return "#"
            }
            let uppercaseChar = String(firstChar).uppercased()
            
            let cyrillicPattern = "^[А-ЯЁ]$"
            let latinPattern = "^[A-Z]$"
            
            if uppercaseChar.range(of: cyrillicPattern, options: .regularExpression) != nil {
                return uppercaseChar
            } else if uppercaseChar.range(of: latinPattern, options: .regularExpression) != nil {
                return uppercaseChar
            } else {
                return "#"
            }
        }
        
        return grouped.sorted { sec1, sec2 in
            let label1 = sec1.key
            let label2 = sec2.key
            
            if label1 == "#" { return false }
            if label2 == "#" { return true }
            
            let isCyr1 = label1.range(of: "^[А-ЯЁ]$", options: .regularExpression) != nil
            let isCyr2 = label2.range(of: "^[А-ЯЁ]$", options: .regularExpression) != nil
            
            if isCyr1 && !isCyr2 { return true }
            if !isCyr1 && isCyr2 { return false }
            
            return label1.localizedStandardCompare(label2) == .orderedAscending
        }
    }

    private var sectionLetters: [String] {
        groupedByLetter.map { $0.0 }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .topTrailing) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if sortedFriends.isEmpty {
                                emptyState
                            } else if sortOrder == .alphabet {
                                ForEach(groupedByLetter, id: \.0) { letter, users in
                                    VStack(spacing: 0) {
                                        sectionHeader(letter)
                                        ForEach(users) { user in
                                            NavigationLink(destination: ProfileView(user: user, selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                                                friendRow(user)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            SectionSeparator()
                                        }
                                    }
                                    .id(letter)
                                }
                            } else {
                                ForEach(sortedFriends) { user in
                                    NavigationLink(destination: ProfileView(user: user, selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                                        friendRow(user)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    SectionSeparator()
                                }
                            }
                        }
                    }

                    if sortOrder == .alphabet && !sortedFriends.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(sectionLetters, id: \.self) { letter in
                                Text(letter)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(dragSelectedLetter == letter ? Color(.label) : .appAccent)
                                    .scaleEffect(dragSelectedLetter == letter ? 1.3 : 1.0)
                                    .frame(width: 24, height: 16)
                            }
                            Spacer()
                        }
                        .background(Color.clear)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let y = value.location.y
                                    let index = Int(y / 16)
                                    let clampedIndex = max(0, min(sectionLetters.count - 1, index))
                                    let letter = sectionLetters[clampedIndex]
                                    if dragSelectedLetter != letter {
                                        dragSelectedLetter = letter
                                        HapticManager.impact(.light)
                                        proxy.scrollTo(letter, anchor: .top)
                                    }
                                }
                                .onEnded { _ in
                                    dragSelectedLetter = nil
                                }
                        )
                        .padding(.trailing, 2)
                        .padding(.top, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Друзья")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton(title: "Назад")
        .toolbar { toolbarContent }
        .searchable(text: $searchQuery, prompt: "Поиск друзей")
        .refreshable {
            await refresh()
        }
        .onAppear {
            loadFriends()
        }
    }

    private func refresh() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            loadFriends {
                continuation.resume()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 60)
            Image(systemName: "person.slash")
                .font(.system(size: 40))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Ничего не найдено")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
    }

    private func friendRow(_ user: User) -> some View {
        HStack(spacing: 14) {
            ZStack {
                if let url = user.avatarURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color(.tertiarySystemFill))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(.secondaryLabel))
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    if user.isOfficial == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.appAccent)
                    }
                    SupporterBadgeView(screenName: user.username, size: 16)
                }

                if user.isOnline {
                    HStack(spacing: 4) {
                        Text("В сети")
                            .font(.system(size: 14))
                            .foregroundColor(.appAccent)
                        if let platform = user.onlinePlatform {
                            PlatformIconView(platform: platform, size: 11, color: .appAccent)
                        }
                    }
                } else if let lastSeen = user.lastSeen {
                    HStack(spacing: 4) {
                        Text(lastSeen)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        if let platform = user.onlinePlatform {
                            PlatformIconView(platform: platform, size: 11, color: .secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func sectionHeader(_ letter: String) -> some View {
        HStack {
            Text(letter)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.systemGroupedBackground))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("Сортировка", selection: $sortOrder) {
                    ForEach(FriendSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appAccent)
            }
        }
    }

    private func loadFriends(completion: (() -> Void)? = nil) {
        isLoading = friends.isEmpty
        errorMessage = nil
        
        APIClient.shared.call(
            method: "friends.get",
            parameters: [
                "user_id": "\(ownerID)",
                "fields": "photo_100,photo_200,city,online,status,friend_status,counters,about,personal,sex,site,last_seen",
                "count": "100"
            ],
            httpMethod: "GET",
            as: VKSearchResponseInner<VKUserProfile>.self
        ) { result in
            isLoading = false
            switch result {
            case .success(let inner):
                let mapped = (inner.items ?? []).map { vkUser -> User in
                    let name = "\(vkUser.firstName ?? "") \(vkUser.lastName ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
                    let lastSeenText: String?
                    if let ls = vkUser.lastSeen?.time {
                        let date = Date(timeIntervalSince1970: ls)
                        lastSeenText = date.openvkLastSeen(sex: vkUser.sex)
                    } else {
                        lastSeenText = nil
                    }
                    return User(
                        uid: vkUser.id,
                        username: vkUser.screenName ?? "id\(vkUser.id)",
                        displayName: name.isEmpty ? "Пользователь" : name,
                        avatarURL: (vkUser.photo200 ?? vkUser.photo100).flatMap { URL(string: $0) },
                        city: vkUser.city?.title,
                        isOnline: vkUser.online == 1,
                        onlinePlatform: vkUser.lastSeen?.platformName,
                        lastSeen: lastSeenText,
                        isFriend: vkUser.friendStatus == 3,
                        status: vkUser.status,
                        photoCount: vkUser.counters?.photos,
                        about: vkUser.about,
                        site: vkUser.site
                    )
                }
                self.friends = mapped
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
            completion?()
        }
    }
}
