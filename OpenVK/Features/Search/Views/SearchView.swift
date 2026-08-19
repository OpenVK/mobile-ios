//
//  SearchView.swift
//  OpenVK for iOS
//
//  Экран поиска по всем разделам.
//

import SwiftUI

struct SearchView: View {

    @StateObject private var viewModel = SearchViewModel()
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?
    
    @State private var selectedProfileUser: User? = nil
    @State private var playingTrackId: UUID? = nil
    @State private var downloadingDocId: Int? = nil

    init(selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }

    private let videoColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchHeaderView
                categoryScrollView
                filterBarView
                
                Divider()

                ZStack {
                    Color(.systemBackground)
                        .edgesIgnoringSafeArea(.all)

                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.isCurrentResultsEmpty {
                        emptyResultsView
                    } else {
                        resultsContentView
                    }
                }
            }
            .navigationBarHidden(true)
            .background(navigationDestinationLink)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var searchHeaderView: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(.secondaryLabel))
                    .font(.system(size: 16, weight: .medium))

                TextField("Поиск по людям, группам, музыке...", text: $viewModel.query)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        viewModel.performSearch(viewModel.query, force: true)
                    }

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !viewModel.query.isEmpty {
                    Button(action: {
                        HapticManager.impact(.light)
                        viewModel.clearQuery()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.tertiaryLabel))
                            .font(.system(size: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchCategory.allCases) { category in
                    let isSelected = viewModel.selectedCategory == category
                    Button(action: {
                        HapticManager.impact(.light)
                        viewModel.selectCategory(category)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                            Text(category.title)
                                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundColor(isSelected ? .white : Color(.label))
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.appAccent : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var filterBarView: some View {
        if viewModel.selectedCategory != .all && viewModel.selectedCategory != .posts {
            HStack {
                Text(categoryItemCountText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                filterMenu
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var isFilterActive: Bool {
        switch viewModel.selectedCategory {
        case .all, .posts:
            return false
        case .users:
            return viewModel.userSort != .popular || viewModel.userOnlyOnline
        case .groups:
            return viewModel.groupSort != .byMembers
        case .videos:
            return viewModel.videoSort != .byDate
        case .audios:
            return viewModel.audioSort != .byPopularity || viewModel.audioPerformerOnly || viewModel.audioWithLyrics
        case .documents:
            return viewModel.docType != .all
        }
    }

    private var categoryItemCountText: String {
        switch viewModel.selectedCategory {
        case .all:
            return ""
        case .users:
            let count = max(viewModel.totalUsersCount, viewModel.users.count)
            return count > 0 ? "\(count) пользователей" : ""
        case .groups:
            let count = max(viewModel.totalGroupsCount, viewModel.groups.count)
            return count > 0 ? "\(count) групп" : ""
        case .posts:
            return viewModel.posts.count > 0 ? "\(viewModel.posts.count) записей" : ""
        case .videos:
            let count = max(viewModel.totalVideosCount, viewModel.videos.count)
            return count > 0 ? "\(count) видео" : ""
        case .audios:
            let count = max(viewModel.totalAudiosCount, viewModel.audios.count)
            return count > 0 ? "\(count) аудиозаписей" : ""
        case .documents:
            let count = max(viewModel.totalDocumentsCount, viewModel.documents.count)
            return count > 0 ? "\(count) документов" : ""
        }
    }

    private var filterMenu: some View {
        Menu {
            switch viewModel.selectedCategory {
            case .all:
                EmptyView()
            case .users:
                Section("Сортировка") {
                    Picker("Сортировка", selection: $viewModel.userSort) {
                        ForEach(UserSortOption.allCases) { opt in
                            Text(opt.title).tag(opt)
                        }
                    }
                }
                Section("Фильтр") {
                    Toggle(isOn: $viewModel.userOnlyOnline) {
                        Label("Только онлайн", systemImage: "circle.fill")
                    }
                }
            case .groups:
                Section("Сортировка") {
                    Picker("Сортировка", selection: $viewModel.groupSort) {
                        ForEach(GroupSortOption.allCases) { opt in
                            Text(opt.title).tag(opt)
                        }
                    }
                }
            case .posts:
                EmptyView()
            case .videos:
                Section("Сортировка") {
                    Picker("Сортировка", selection: $viewModel.videoSort) {
                        ForEach(VideoSortOption.allCases) { opt in
                            Text(opt.title).tag(opt)
                        }
                    }
                }
            case .audios:
                Section("Сортировка") {
                    Picker("Сортировка", selection: $viewModel.audioSort) {
                        ForEach(AudioSortOption.allCases) { opt in
                            Text(opt.title).tag(opt)
                        }
                    }
                }
                Section("Параметры поиска") {
                    Toggle(isOn: $viewModel.audioPerformerOnly) {
                        Label("Только по исполнителю", systemImage: "person.wave.2")
                    }
                    Toggle(isOn: $viewModel.audioWithLyrics) {
                        Label("С текстом песни", systemImage: "text.quote")
                    }
                }
            case .documents:
                Section("Тип документа") {
                    Picker("Тип документа", selection: $viewModel.docType) {
                        ForEach(DocTypeFilter.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                Text(viewModel.activeSortDescription)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(isFilterActive ? .appAccent : Color(.secondaryLabel))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var navigationDestinationLink: some View {
        NavigationLink(
            destination: Group {
                if let user = selectedProfileUser {
                    ProfileView(
                        user: user,
                        selectedMedia: $selectedMedia,
                        owningPost: $owningPost
                    )
                }
            },
            isActive: Binding(
                get: { selectedProfileUser != nil },
                set: { if !$0 { selectedProfileUser = nil } }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var resultsContentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch viewModel.selectedCategory {
                case .all:
                    allSummaryView
                case .users:
                    usersFullListView
                case .groups:
                    groupsFullListView
                case .posts:
                    postsFullListView
                case .videos:
                    videosFullGridView
                case .audios:
                    audiosFullListView
                case .documents:
                    documentsFullListView
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var isContentEmpty: Bool {
        switch viewModel.selectedCategory {
        case .all: return viewModel.allResults.isEmpty
        case .users: return viewModel.users.isEmpty
        case .groups: return viewModel.groups.isEmpty
        case .posts: return viewModel.posts.isEmpty
        case .videos: return viewModel.videos.isEmpty
        case .audios: return viewModel.audios.isEmpty
        case .documents: return viewModel.documents.isEmpty
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Поиск...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(.bottom, 4)

            Text("Ничего не найдено")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)

            Text("По запросу «\(viewModel.query)» ничего не нашлось.\nПопробуйте изменить запрос или поискать в других разделах.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    private var allSummaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            let res = viewModel.allResults

            if !res.users.isEmpty {
                sectionHeader(title: "Люди", count: res.users.count, category: .users)
                VStack(spacing: 0) {
                    ForEach(res.users.prefix(3)) { user in
                        userRow(user)
                        SectionSeparator()
                    }
                }
            }

            if !res.groups.isEmpty {
                sectionHeader(title: "Сообщества", count: res.groups.count, category: .groups)
                VStack(spacing: 0) {
                    ForEach(res.groups.prefix(3)) { group in
                        groupRow(group)
                        SectionSeparator()
                    }
                }
            }

            if !res.audios.isEmpty {
                sectionHeader(title: "Музыка", count: res.audios.count, category: .audios)
                VStack(spacing: 0) {
                    ForEach(res.audios.prefix(3)) { track in
                        audioRow(track)
                        SectionSeparator()
                    }
                }
            }

            if !res.videos.isEmpty {
                sectionHeader(title: "Видеозаписи", count: res.videos.count, category: .videos)
                LazyVGrid(columns: videoColumns, spacing: 12) {
                    ForEach(res.videos.prefix(4)) { video in
                        videoGridItem(video, allVideos: res.videos)
                    }
                }
                .padding(.horizontal, 16)
            }

            if !res.posts.isEmpty {
                sectionHeader(title: "Записи", count: res.posts.count, category: .posts)
                VStack(spacing: 8) {
                    ForEach(res.posts.prefix(3)) { post in
                        PostCard(
                            post: post,
                            showCommentsButton: true,
                            showCommentPreview: false,
                            selectedMedia: $selectedMedia,
                            owningPost: $owningPost
                        )
                        SectionSeparator()
                    }
                }
            }

            if !res.documents.isEmpty {
                sectionHeader(title: "Документы", count: res.documents.count, category: .documents)
                VStack(spacing: 0) {
                    ForEach(res.documents.prefix(3)) { doc in
                        documentRow(doc)
                        SectionSeparator()
                    }
                }
            }
        }
        .padding(.top, 10)
    }

    private func sectionHeader(title: String, count: Int, category: SearchCategory) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                HapticManager.impact(.light)
                viewModel.selectCategory(category)
            }) {
                HStack(spacing: 2) {
                    Text("Показать все")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.appAccent)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var usersFullListView: some View {
        ForEach(viewModel.users) { user in
            userRow(user)
                .onAppear {
                    if user.id == viewModel.users.last?.id {
                        viewModel.loadMore()
                    }
                }
            SectionSeparator()
        }
        if viewModel.isLoadingMore {
            paginationLoadingView
        }
    }

    @ViewBuilder
    private var groupsFullListView: some View {
        ForEach(viewModel.groups) { group in
            groupRow(group)
                .onAppear {
                    if group.id == viewModel.groups.last?.id {
                        viewModel.loadMore()
                    }
                }
            SectionSeparator()
        }
        if viewModel.isLoadingMore {
            paginationLoadingView
        }
    }

    @ViewBuilder
    private var postsFullListView: some View {
        ForEach(viewModel.posts) { post in
            PostCard(
                post: post,
                showCommentsButton: true,
                showCommentPreview: true,
                selectedMedia: $selectedMedia,
                owningPost: $owningPost
            )
            .onAppear {
                if post.id == viewModel.posts.last?.id {
                    viewModel.loadMore()
                }
            }
            .padding(.top, 6)
            SectionSeparator()
        }
        if viewModel.isLoadingMore {
            paginationLoadingView
        }
    }

    @ViewBuilder
    private var videosFullGridView: some View {
        LazyVGrid(columns: videoColumns, spacing: 12) {
            ForEach(viewModel.videos) { video in
                videoGridItem(video, allVideos: viewModel.videos)
                    .onAppear {
                        if video.id == viewModel.videos.last?.id {
                            viewModel.loadMore()
                        }
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        
        if viewModel.isLoadingMore {
            paginationLoadingView
        }
    }

    @ViewBuilder
    private var audiosFullListView: some View {
        ForEach(viewModel.audios) { track in
            audioRow(track)
                .onAppear {
                    if track.id == viewModel.audios.last?.id {
                        viewModel.loadMore()
                    }
                }
            SectionSeparator()
        }
        if viewModel.isLoadingMore {
            paginationLoadingView
        }
    }

    @ViewBuilder
    private var documentsFullListView: some View {
        ForEach(viewModel.documents) { doc in
            documentRow(doc)
                .onAppear {
                    if doc.id == viewModel.documents.last?.id {
                        viewModel.loadMore()
                    }
                }
            SectionSeparator()
        }
        if viewModel.isLoadingMore {
            paginationLoadingView
        }
    }

    private var paginationLoadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.vertical, 16)
            Spacer()
        }
    }

    private func userRow(_ user: User) -> some View {
        Button(action: {
            selectedProfileUser = user
        }) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(user: user, size: 48)

                    if user.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 2)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(user.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if user.isOfficial == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.appAccent)
                        }
                        SupporterBadgeView(screenName: user.username, size: 12)
                    }

                    if user.isOnline {
                        HStack(spacing: 4) {
                            Text("В сети")
                                .font(.system(size: 13))
                                .foregroundColor(.appAccent)
                            if let platform = user.onlinePlatform {
                                PlatformIconView(platform: platform, size: 10, color: .appAccent)
                            }
                        }
                    } else if let lastSeen = user.lastSeen, !lastSeen.isEmpty {
                        HStack(spacing: 4) {
                            Text(lastSeen)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            if let platform = user.onlinePlatform {
                                PlatformIconView(platform: platform, size: 10, color: .secondary)
                            }
                        }
                    } else if let status = user.status, !status.isEmpty {
                        Text(status)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if let city = user.city, !city.isEmpty {
                        Text(city)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func groupRow(_ group: Community) -> some View {
        Button(action: {
            selectedProfileUser = group.toUser()
        }) {
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
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(.secondaryLabel))
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(group.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if group.isOfficial {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.appAccent)
                        }
                        SupporterBadgeView(screenName: group.screenName, size: 12)
                    }

                    Text("\(group.memberCount) участников")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func audioRow(_ track: AudioTrack) -> some View {
        let isPlaying = playingTrackId == track.id
        return HStack(spacing: 12) {
            Button(action: {
                HapticManager.impact(.light)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    if playingTrackId == track.id {
                        playingTrackId = nil
                    } else {
                        playingTrackId = track.id
                    }
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(track.color)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: isPlaying ? 0 : 1)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isPlaying ? .appAccent : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.duration)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func videoGridItem(_ video: Video, allVideos: [Video]) -> some View {
        Button(action: {
            let videoAttachment = Attachment.remoteVideo(
                title: video.title,
                duration: video.duration,
                imageURL: video.imageURL?.absoluteString ?? "",
                videoURL: video.playerURL?.absoluteString,
                id: video.vkID,
                ownerID: video.ownerID,
                files: video.files,
                likesCount: video.likesCount,
                commentsCount: video.commentsCount,
                repostsCount: video.repostsCount,
                isLiked: video.isLiked
            )
            
            let attachments = allVideos.map { v -> Attachment in
                Attachment.remoteVideo(
                    title: v.title,
                    duration: v.duration,
                    imageURL: v.imageURL?.absoluteString ?? "",
                    videoURL: v.playerURL?.absoluteString,
                    id: v.vkID,
                    ownerID: v.ownerID,
                    files: v.files,
                    likesCount: v.likesCount,
                    commentsCount: v.commentsCount,
                    repostsCount: v.repostsCount,
                    isLiked: v.isLiked
                )
            }
            
            let dummyPost = Post(
                author: User(username: "search_video", displayName: "Видео"),
                timeAgo: "",
                text: "",
                attachments: attachments
            )
            
            withAnimation(.easeInOut(duration: 0.25)) {
                self.owningPost = dummyPost
                self.selectedMedia = videoAttachment
            }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    if let url = video.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                            default:
                                Rectangle()
                                    .fill(Color(.secondarySystemBackground))
                                    .aspectRatio(16/9, contentMode: .fill)
                                    .overlay(
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color(.tertiaryLabel))
                                    )
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .aspectRatio(16/9, contentMode: .fill)
                            .overlay(
                                Image(systemName: "video.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(.tertiaryLabel))
                            )
                    }

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    Text(video.duration)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(4)
                        .padding(6)
                }
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(10)

                Text(video.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func documentRow(_ doc: AppDocument) -> some View {
        let isDownloading = downloadingDocId == doc.id
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appAccent.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.appAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(doc.ext.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.appAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.appAccent.opacity(0.12))
                        .cornerRadius(3)

                    Text(doc.formattedSize)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                guard !isDownloading else { return }
                HapticManager.impact(.light)
                downloadingDocId = doc.id
                var dlBinding = true
                DocumentDownloader.downloadAndShare(
                    url: doc.url,
                    title: doc.title,
                    ext: doc.ext,
                    isDownloading: Binding(
                        get: { dlBinding },
                        set: { dlBinding = $0; if !$0 { downloadingDocId = nil } }
                    )
                )
            }) {
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.appAccent)
                        .frame(width: 28, height: 28)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDownloading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
