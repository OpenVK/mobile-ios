//
//  GroupsListView.swift
//  OpenVK for iOS
//
//  Экран списка групп.
//

import SwiftUI

enum GroupSortOrder: String, CaseIterable {
    case online = "По активности"
    case alphabet = "По алфавиту"
}

struct VKGroupsResponseInner: Decodable {
    let count: Int?
    let items: [VKSearchGroup]?
}

struct VKSearchGroup: Decodable {
    let id: Int?
    let name: String?
    let screenName: String?
    let photo100: String?
    let membersCount: Int?
    let verified: Int?
    let isAdmin: Bool?
    let canPost: Bool?
    let canSuggest: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case screenName = "screen_name"
        case screenNameCamel = "screenName"
        case photo100 = "photo_100"
        case photo100Camel = "photo100"
        case membersCount = "members_count"
        case membersCountCamel = "membersCount"
        case verified
        case isAdmin = "is_admin"
        case isAdminCamel = "isAdmin"
        case canPost = "can_post"
        case canPostCamel = "canPost"
        case canSuggest = "can_suggest"
        case canSuggestCamel = "canSuggest"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(Int.self, forKey: .id)
        name = try? container.decode(String.self, forKey: .name)
        screenName = (try? container.decode(String.self, forKey: .screenName)) ?? (try? container.decode(String.self, forKey: .screenNameCamel))
        photo100 = (try? container.decode(String.self, forKey: .photo100)) ?? (try? container.decode(String.self, forKey: .photo100Camel))
        membersCount = (try? container.decode(Int.self, forKey: .membersCount)) ?? (try? container.decode(Int.self, forKey: .membersCountCamel))
        if let intVal = try? container.decode(Int.self, forKey: .verified) {
            verified = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .verified) {
            verified = boolVal ? 1 : 0
        } else {
            verified = nil
        }
        
        if let boolVal = (try? container.decode(Bool.self, forKey: .isAdmin)) ?? (try? container.decode(Bool.self, forKey: .isAdminCamel)) {
            isAdmin = boolVal
        } else if let intVal = (try? container.decode(Int.self, forKey: .isAdmin)) ?? (try? container.decode(Int.self, forKey: .isAdminCamel)) {
            isAdmin = intVal == 1
        } else {
            isAdmin = nil
        }
        
        if let boolVal = (try? container.decode(Bool.self, forKey: .canPost)) ?? (try? container.decode(Bool.self, forKey: .canPostCamel)) {
            canPost = boolVal
        } else if let intVal = (try? container.decode(Int.self, forKey: .canPost)) ?? (try? container.decode(Int.self, forKey: .canPostCamel)) {
            canPost = intVal == 1
        } else {
            canPost = nil
        }
        
        if let boolVal = (try? container.decode(Bool.self, forKey: .canSuggest)) ?? (try? container.decode(Bool.self, forKey: .canSuggestCamel)) {
            canSuggest = boolVal
        } else if let intVal = (try? container.decode(Int.self, forKey: .canSuggest)) ?? (try? container.decode(Int.self, forKey: .canSuggestCamel)) {
            canSuggest = intVal == 1
        } else {
            canSuggest = nil
        }
    }
}

struct GroupsListView: View {

    let ownerID: Int
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?
    @State private var groups: [Community] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    init(ownerID: Int, selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        self.ownerID = ownerID
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }
    
    @State private var sortOrder: GroupSortOrder = .online
    @State private var searchQuery = ""
    @State private var dragSelectedLetter: String? = nil

    private var filteredGroups: [Community] {
        if searchQuery.isEmpty {
            return groups
        }
        return groups.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var sortedGroups: [Community] {
        switch sortOrder {
        case .online:
            return filteredGroups.sorted { $0.memberCount > $1.memberCount }
        case .alphabet:
            return filteredGroups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    private var groupedByLetter: [(String, [Community])] {
        let grouped = Dictionary(grouping: sortedGroups) { group -> String in
            guard let firstChar = group.name.trimmingCharacters(in: .whitespacesAndNewlines).first else {
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
                            if sortedGroups.isEmpty {
                                emptyState
                            } else if sortOrder == .alphabet {
                                ForEach(groupedByLetter, id: \.0) { letter, groups in
                                    VStack(spacing: 0) {
                                        sectionHeader(letter)
                                        ForEach(groups) { group in
                                            NavigationLink(destination: ProfileView(user: group.toUser(), selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                                                groupRow(group)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            SectionSeparator()
                                        }
                                    }
                                    .id(letter)
                                }
                            } else {
                                ForEach(sortedGroups) { group in
                                    NavigationLink(destination: ProfileView(user: group.toUser(), selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                                        groupRow(group)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    SectionSeparator()
                                }
                            }
                        }
                    }

                    if sortOrder == .alphabet && !sortedGroups.isEmpty {
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
        .navigationTitle("Группы")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton(title: "Назад")
        .toolbar { toolbarContent }
        .searchable(text: $searchQuery, prompt: "Поиск сообществ")
        .refreshable {
            await refresh()
        }
        .onAppear {
            loadGroups()
        }
    }

    private func refresh() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            loadGroups {
                continuation.resume()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 60)
            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Ничего не найдено")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
    }

    private func groupRow(_ group: Community) -> some View {
        HStack(spacing: 14) {
            ZStack {
                if let photoUrl = group.photo100, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemFill))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.3")
                                .font(.system(size: 18))
                                .foregroundColor(Color(.secondaryLabel))
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if group.isOfficial {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.appAccent)
                    }
                    SupporterBadgeView(screenName: group.screenName, size: 12)
                }

                Text("\(group.memberCount) участников")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
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
                    ForEach(GroupSortOrder.allCases, id: \.self) { order in
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

    private func loadGroups(completion: (() -> Void)? = nil) {
        isLoading = groups.isEmpty
        errorMessage = nil
        
        let params: [String: String] = [
            "user_id": "\(ownerID)",
            "extended": "1",
            "fields": "members_count,status,description,site,verified,can_post,is_admin,can_suggest",
            "count": "100"
        ]
        
        APIClient.shared.call(
            method: "groups.get",
            parameters: params,
            httpMethod: "GET",
            as: VKGroupsResponseInner.self
        ) { result in
            isLoading = false
            switch result {
            case .success(let inner):
                let items = inner.items ?? []
                var mapped: [Community] = []
                for vkGroup in items {
                    let community = Community(
                        vkID: vkGroup.id,
                        name: vkGroup.name ?? "Сообщество",
                        screenName: vkGroup.screenName,
                        photo100: vkGroup.photo100,
                        memberCount: vkGroup.membersCount ?? 0,
                        isOfficial: vkGroup.verified == 1,
                        isAdmin: vkGroup.isAdmin == true,
                        canPost: vkGroup.canPost == true,
                        canSuggest: vkGroup.canSuggest == true
                    )
                    mapped.append(community)
                }
                self.groups = mapped
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
            completion?()
        }
    }
}
