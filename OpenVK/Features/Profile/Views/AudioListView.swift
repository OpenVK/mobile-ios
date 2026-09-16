//
//  AudioListView.swift
//  OpenVK for iOS
//
//  Экран аудиозаписей и глобальный аудиоплеер.
//

import SwiftUI

private enum AudioLibraryTab: Int, CaseIterable {
    case mine
    case popular

    var title: String {
        switch self {
        case .mine: return "Моя музыка"
        case .popular: return "Популярная"
        }
    }
}

struct AudioListView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var viewModel = AudioLibraryViewModel()
    @ObservedObject private var player = AudioPlayerService.shared
    @State private var searchQuery = ""
    @State private var selectedTab: AudioLibraryTab = .mine

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchQuery.isEmpty
    }

    private var displayedTracks: [AudioTrack] {
        if isSearching {
            return viewModel.searchResults
        }
        switch selectedTab {
        case .mine: return viewModel.tracks
        case .popular: return viewModel.popularTracks
        }
    }

    private var isCurrentSectionLoading: Bool {
        if isSearching {
            return viewModel.isSearching && viewModel.searchResults.isEmpty
        }
        switch selectedTab {
        case .mine:
            return viewModel.isLoading && viewModel.tracks.isEmpty && viewModel.playlists.isEmpty
        case .popular:
            return viewModel.isLoadingPopular && viewModel.popularTracks.isEmpty
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if !isSearching {
                    Picker("Раздел", selection: $selectedTab) {
                        ForEach(AudioLibraryTab.allCases, id: \.self) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                if isCurrentSectionLoading {
                    AudioLibraryLoadingView()
                        .padding(.top, 12)
                } else if isSearching {
                    searchResultsSection
                } else {
                    if selectedTab == .mine && !isSearching {
                        playlistsSection
                    }
                    tracksSection
                }

                if let message = viewModel.errorMessage, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, player.currentTrack == nil ? 24 : 92)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Музыка")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: "Поиск по всей музыке")
        .customBackButton(title: "Назад")
        .refreshable {
            await refresh()
        }
        .onAppear {
            guard let ownerID = auth.currentUser?.uid else { return }
            viewModel.load(ownerID: ownerID)
        }
        .onChange(of: selectedTab) { tab in
            if tab == .popular && !isSearching {
                viewModel.loadPopular()
            }
        }
        .onChange(of: searchQuery) { query in
            viewModel.search(query: query)
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               selectedTab == .popular {
                viewModel.loadPopular()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openvkAudioLibraryDidChange)) { _ in
            guard let ownerID = auth.currentUser?.uid else { return }
            viewModel.load(ownerID: ownerID, force: true)
        }
    }

    @ViewBuilder
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ПЛЕЙЛИСТЫ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)

            if viewModel.playlists.isEmpty {
                Text("You haven't added any playlists yet.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.playlists) { playlist in
                            NavigationLink(destination: AudioPlaylistDetailView(playlist: playlist)) {
                                AudioPlaylistCard(playlist: playlist)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(sectionTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            if displayedTracks.isEmpty && !isCurrentSectionLoading {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 34))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text(emptyText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                ForEach(displayedTracks) { track in
                    AudioTrackRow(track: track, queue: displayedTracks)
                        .padding(.horizontal, 16)
                        .onAppear {
                            if track.id == displayedTracks.last?.id,
                               selectedTab == .popular,
                               viewModel.hasMorePopular {
                                viewModel.loadMorePopular()
                            }
                        }
                    SectionSeparator()
                }

                if viewModel.isLoadingMorePopular {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 12)
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if !viewModel.searchPlaylists.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ПЛЕЙЛИСТЫ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.searchPlaylists) { playlist in
                            NavigationLink(destination: AudioPlaylistDetailView(playlist: playlist)) {
                                AudioPlaylistCard(playlist: playlist)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

        VStack(alignment: .leading, spacing: 0) {
            Text("ТРЕКИ")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            if viewModel.searchResults.isEmpty && !viewModel.isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 34))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("Ничего не найдено")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                ForEach(viewModel.searchResults) { track in
                    AudioTrackRow(track: track, queue: viewModel.searchResults)
                        .padding(.horizontal, 16)
                        .onAppear {
                            if track.id == viewModel.searchResults.last?.id,
                               viewModel.hasMoreSearchResults {
                                viewModel.loadMoreSearchResults()
                            }
                        }
                    SectionSeparator()
                }

                if viewModel.isLoadingMoreSearch {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 12)
                        Spacer()
                    }
                }
            }
        }
    }

    private var sectionTitle: String {
        if isSearching { return "РЕЗУЛЬТАТЫ ПОИСКА" }
        return selectedTab == .mine ? "АУДИОЗАПИСИ" : "ПОПУЛЯРНОЕ"
    }

    private var emptyText: String {
        if isSearching { return "Ничего не найдено" }
        return selectedTab == .mine
            ? "В вашей коллекции пока нет аудиозаписей"
            : "Популярные аудиозаписи пока недоступны"
    }

    private func refresh() async {
        if isSearching {
            await withCheckedContinuation { continuation in
                viewModel.search(query: searchQuery, force: true) {
                    continuation.resume()
                }
            }
            return
        }

        switch selectedTab {
        case .mine:
            guard let ownerID = auth.currentUser?.uid else { return }
            await withCheckedContinuation { continuation in
                viewModel.load(ownerID: ownerID, force: true) {
                    continuation.resume()
                }
            }
        case .popular:
            await withCheckedContinuation { continuation in
                viewModel.loadPopular(force: true) {
                    continuation.resume()
                }
            }
        }
    }
}

private final class AudioLibraryViewModel: ObservableObject {
    @Published var playlists: [AudioPlaylist] = []
    @Published var tracks: [AudioTrack] = []
    @Published var popularTracks: [AudioTrack] = []
    @Published var searchResults: [AudioTrack] = []
    @Published var searchPlaylists: [AudioPlaylist] = []
    @Published var isLoading = false
    @Published var isLoadingPopular = false
    @Published var isLoadingMorePopular = false
    @Published var hasMorePopular = true
    @Published var isSearching = false
    @Published var isLoadingMoreSearch = false
    @Published var hasMoreSearchResults = true
    @Published var errorMessage: String?

    private var loadedOwnerID: Int?
    private var didLoadPopular = false
    private let popularPageSize = 50
    private var searchWorkItem: DispatchWorkItem?
    private var searchGeneration = 0
    private var searchOffset = 0
    private var lastSearchQuery = ""
    private let searchPageSize = 50

    func load(ownerID: Int, force: Bool = false, completion: (() -> Void)? = nil) {
        if !force, loadedOwnerID == ownerID, (!playlists.isEmpty || !tracks.isEmpty) {
            completion?()
            return
        }

        isLoading = true
        errorMessage = nil
        loadedOwnerID = ownerID

        let group = DispatchGroup()
        var firstError: String?

        group.enter()
        AudioService.shared.getPlaylists(ownerID: ownerID) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let playlists) = result {
                    self?.playlists = playlists
                } else if case .failure(let error) = result {
                    firstError = error.localizedDescription
                }
                group.leave()
            }
        }

        group.enter()
        AudioService.shared.getTracks(ownerID: ownerID) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let tracks) = result {
                    self?.tracks = tracks
                    AudioLibraryMembership.shared.seedAdded(tracks)
                } else if case .failure(let error) = result {
                    firstError = firstError ?? error.localizedDescription
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            self?.errorMessage = firstError
            completion?()
        }
    }

    func loadPopular(force: Bool = false, completion: (() -> Void)? = nil) {
        if didLoadPopular && !force {
            completion?()
            return
        }

        isLoadingPopular = true
        hasMorePopular = true
        errorMessage = nil
        AudioService.shared.getPopularTracks(offset: 0, count: popularPageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let tracks):
                    self.popularTracks = tracks
                    self.hasMorePopular = tracks.count >= self.popularPageSize
                    self.didLoadPopular = true
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                self.isLoadingPopular = false
                completion?()
            }
        }
    }

    func loadMorePopular(completion: (() -> Void)? = nil) {
        guard !isLoadingPopular, !isLoadingMorePopular, hasMorePopular else {
            completion?()
            return
        }

        isLoadingMorePopular = true

        AudioService.shared.getPopularTracks(offset: popularTracks.count, count: popularPageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion?()
                    return
                }
                switch result {
                case .success(let tracks):
                    self.popularTracks.append(contentsOf: tracks)
                    self.hasMorePopular = tracks.count >= self.popularPageSize
                case .failure:
                    self.hasMorePopular = false
                }
                self.isLoadingMorePopular = false
                completion?()
            }
        }
    }

    func search(query: String, force: Bool = false, completion: (() -> Void)? = nil) {
        searchWorkItem?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchGeneration += 1
        let generation = searchGeneration

        guard !trimmed.isEmpty else {
            searchResults = []
            searchPlaylists = []
            isSearching = false
            searchOffset = 0
            hasMoreSearchResults = true
            lastSearchQuery = ""
            errorMessage = nil
            completion?()
            return
        }

        lastSearchQuery = trimmed

        let work = DispatchWorkItem { [weak self] in
            guard let self = self, generation == self.searchGeneration else { return }
            self.isSearching = true
            self.searchOffset = 0
            self.hasMoreSearchResults = true
            self.searchResults = []
            self.searchPlaylists = []
            self.errorMessage = nil

            let group = DispatchGroup()
            var tracksError: String?

            group.enter()
            AudioService.shared.searchTracks(query: trimmed, offset: 0, count: self.searchPageSize) { result in
                DispatchQueue.main.async {
                    guard generation == self.searchGeneration else { return }
                    switch result {
                    case .success(let tracks):
                        self.searchResults = tracks
                        self.hasMoreSearchResults = tracks.count >= self.searchPageSize
                    case .failure(let error):
                        tracksError = error.localizedDescription
                    }
                    group.leave()
                }
            }

            group.enter()
            AudioService.shared.searchPlaylists(query: trimmed, offset: 0, count: 10) { result in
                DispatchQueue.main.async {
                    guard generation == self.searchGeneration else { return }
                    switch result {
                    case .success(let playlists):
                        self.searchPlaylists = playlists
                    case .failure:
                        break
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                guard generation == self.searchGeneration else { return }
                self.errorMessage = tracksError
                self.isSearching = false
                completion?()
            }
        }

        searchWorkItem = work
        if force {
            DispatchQueue.main.async(execute: work)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
        }
    }

    func loadMoreSearchResults(completion: (() -> Void)? = nil) {
        guard !isSearching, !isLoadingMoreSearch, hasMoreSearchResults, !lastSearchQuery.isEmpty else {
            completion?()
            return
        }

        isLoadingMoreSearch = true
        let currentOffset = searchOffset + searchResults.count
        let generation = searchGeneration

        AudioService.shared.searchTracks(query: lastSearchQuery, offset: currentOffset, count: searchPageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, generation == self.searchGeneration else {
                    completion?()
                    return
                }
                switch result {
                case .success(let tracks):
                    self.searchResults.append(contentsOf: tracks)
                    self.hasMoreSearchResults = tracks.count >= self.searchPageSize
                case .failure:
                    self.hasMoreSearchResults = false
                }
                self.isLoadingMoreSearch = false
                completion?()
            }
        }
    }
}

private struct AudioPlaylistCard: View {
    let playlist: AudioPlaylist

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AudioArtworkView(playlist: playlist, cornerRadius: 12)
                .frame(width: 132, height: 132)

            Text(playlist.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 132, alignment: .leading)

            Text(trackCountText(playlist.size))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 132, alignment: .leading)
        }
    }

    private func trackCountText(_ count: Int) -> String {
        let lastTwo = count % 100
        if (11...14).contains(lastTwo) { return "\(count) треков" }
        switch count % 10 {
        case 1: return "\(count) трек"
        case 2, 3, 4: return "\(count) трека"
        default: return "\(count) треков"
        }
    }
}

private struct AudioPlaylistDetailView: View {
    let playlist: AudioPlaylist
    @State private var tracks: [AudioTrack] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                VStack(spacing: 10) {
                    AudioArtworkView(playlist: playlist, cornerRadius: 16)
                        .frame(width: 190, height: 190)
                        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 5)

                    Text(playlist.title)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)

                    if !playlist.description.isEmpty {
                        Text(playlist.description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 18)

                if isLoading {
                    ProgressView()
                        .padding(.vertical, 32)
                } else if tracks.isEmpty {
                    Text(errorMessage ?? "В этом плейлисте пока нет аудиозаписей")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                } else {
                    ForEach(tracks) { track in
                        AudioTrackRow(track: track, queue: tracks)
                            .padding(.horizontal, 16)
                        SectionSeparator()
                    }
                }
            }
            .padding(.bottom, AudioPlayerService.shared.currentTrack == nil ? 24 : 92)
        }
        .navigationTitle(playlist.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func load() {
        guard isLoading else { return }
        AudioService.shared.getTracks(
            ownerID: playlist.ownerID,
            playlistID: playlist.id,
            artworkURL: playlist.coverURL
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let resultTracks):
                    tracks = resultTracks
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }
}

struct AudioTrackRow: View {
    let track: AudioTrack
    let queue: [AudioTrack]
    @ObservedObject private var player = AudioPlayerService.shared

    private var isCurrent: Bool {
        guard let current = player.currentTrack else { return false }
        if let lhsOwner = current.ownerID, let rhsOwner = track.ownerID,
           let lhsID = current.vkID, let rhsID = track.vkID {
            return lhsOwner == rhsOwner && lhsID == rhsID
        }
        return current.id == track.id
    }

    var body: some View {
        Button(action: toggleTrack) {
            HStack(spacing: 12) {
                ZStack {
                    AudioArtworkView(track: track, cornerRadius: 8)

                    if isCurrent && player.isPreparing {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.15))
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if isCurrent && player.isPlaying {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.15))
                        AudioPauseBadge()
                    }
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isCurrent ? .appAccent : .primary)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(track.duration)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func toggleTrack() {
        HapticManager.impact(.light)
        if isCurrent {
            player.togglePlayPause()
        } else {
            player.play(track: track, in: queue)
        }
    }
}

struct AudioPauseBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)

            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.gray.opacity(0.82))
                    .frame(width: 4, height: 12)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.gray.opacity(0.82))
                    .frame(width: 4, height: 12)
            }
        }
    }
}

private struct AudioLibraryLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemFill))
                        .frame(width: 132, height: 132)
                }
            }
            .padding(.horizontal, 16)

            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemFill))
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.secondarySystemFill))
                            .frame(width: 180, height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 120, height: 10)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct AudioArtworkView: View {
    let urlString: String?
    let searchTitle: String?
    let searchArtist: String?
    let isPlaylist: Bool
    var cornerRadius: CGFloat = 10

    @State private var asyncResolvedURL: String? = nil
    @State private var resolvedKey: String? = nil

    init(urlString: String?, cornerRadius: CGFloat = 10) {
        self.urlString = urlString
        self.searchTitle = nil
        self.searchArtist = nil
        self.isPlaylist = false
        self.cornerRadius = cornerRadius
    }

    init(track: AudioTrack, cornerRadius: CGFloat = 10) {
        self.urlString = track.artworkURL
        self.searchTitle = track.title
        self.searchArtist = track.artist
        self.isPlaylist = false
        self.cornerRadius = cornerRadius
    }

    init(playlist: AudioPlaylist, cornerRadius: CGFloat = 10) {
        self.urlString = playlist.coverURL
        self.searchTitle = playlist.title
        self.searchArtist = nil
        self.isPlaylist = true
        self.cornerRadius = cornerRadius
    }

    init(urlString: String?, searchTitle: String?, searchArtist: String? = nil, isPlaylist: Bool = false, cornerRadius: CGFloat = 10) {
        self.urlString = urlString
        self.searchTitle = searchTitle
        self.searchArtist = searchArtist
        self.isPlaylist = isPlaylist
        self.cornerRadius = cornerRadius
    }

    private var queryKey: String {
        "\(isPlaylist ? "p" : "t")_\(searchArtist ?? "")_\(searchTitle ?? "")_\(urlString ?? "")"
    }

    private var openVKURL: URL? {
        guard let sanitized = AudioService.sanitizeArtworkURL(urlString) else {
            return nil
        }
        return URL(string: sanitized)
    }

    private var iTunesURL: URL? {
        if let syncURL = synchronousCachedITunesURL,
           let sanitized = AudioService.sanitizeArtworkURL(syncURL) {
            return URL(string: sanitized)
        }

        if resolvedKey == queryKey,
           let asyncURL = asyncResolvedURL,
           let sanitized = AudioService.sanitizeArtworkURL(asyncURL) {
            return URL(string: sanitized)
        }

        return nil
    }

    private var synchronousCachedITunesURL: String? {
        guard openVKURL == nil else { return nil }
        if isPlaylist {
            guard let title = searchTitle, !title.isEmpty else { return nil }
            return ITunesArtworkService.shared.cachedPlaylistArtworkURL(title: title)
        } else {
            guard let title = searchTitle, let artist = searchArtist,
                  !title.isEmpty || !artist.isEmpty else { return nil }
            return ITunesArtworkService.shared.cachedTrackArtworkURL(artist: artist, title: title)
        }
    }

    private var activeURL: URL? {
        openVKURL ?? iTunesURL
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            if let url = activeURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        Color.clear
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: queryKey) {
            await loadITunesArtworkIfNeeded()
        }
    }

    private func loadITunesArtworkIfNeeded() async {
        guard openVKURL == nil else {
            await MainActor.run {
                self.resolvedKey = queryKey
                self.asyncResolvedURL = nil
            }
            return
        }

        if synchronousCachedITunesURL != nil {
            return
        }

        let targetKey = queryKey

        if isPlaylist {
            guard let title = searchTitle, !title.isEmpty else { return }
            let found = await ITunesArtworkService.shared.fetchPlaylistArtworkURL(title: title)
            await MainActor.run {
                guard self.queryKey == targetKey else { return }
                self.resolvedKey = targetKey
                self.asyncResolvedURL = found
            }
        } else {
            guard let title = searchTitle, let artist = searchArtist,
                  !title.isEmpty || !artist.isEmpty else { return }
            let found = await ITunesArtworkService.shared.fetchTrackArtworkURL(artist: artist, title: title)
            await MainActor.run {
                guard self.queryKey == targetKey else { return }
                self.resolvedKey = targetKey
                self.asyncResolvedURL = found
            }
        }
    }

    private var placeholder: some View {
        GeometryReader { geometry in
            Image(systemName: "music.note")
                .font(.system(
                    size: min(76, max(20, geometry.size.width * 0.25)),
                    weight: .medium
                ))
                .foregroundColor(Color(.secondaryLabel))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Global player overlay

private final class AudioKeyboardObserver: ObservableObject {
    @Published var endFrame: CGRect = .null

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.easeOut(duration: duration)) {
                self.endFrame = frame
            }
        })
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.easeOut(duration: duration)) {
                self?.endFrame = .null
            }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}

private struct TabBarAccessor: UIViewRepresentable {
    @Binding var tabBarTopInset: CGFloat

    func makeUIView(context: Context) -> TabBarTrackerView {
        let view = TabBarTrackerView()
        view.isUserInteractionEnabled = false
        view.onUpdate = { topInset in
            if abs(tabBarTopInset - topInset) > 0.5 {
                DispatchQueue.main.async {
                    tabBarTopInset = topInset
                }
            }
        }
        return view
    }

    func updateUIView(_ uiView: TabBarTrackerView, context: Context) {
        uiView.isUserInteractionEnabled = false
        uiView.onUpdate = { topInset in
            if abs(tabBarTopInset - topInset) > 0.5 {
                DispatchQueue.main.async {
                    tabBarTopInset = topInset
                }
            }
        }
    }
}

private final class TabBarTrackerView: UIView {
    var onUpdate: ((CGFloat) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        checkTabBar()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        checkTabBar()
    }

    private func checkTabBar() {
        guard let window = self.window else { return }
        if let bar = findTabBar(in: window), !bar.isHidden {
            let rect = bar.convert(bar.bounds, to: window)
            if rect.height > 0 && rect.minY > 0 {
                let inset = max(0, window.bounds.height - rect.minY)
                onUpdate?(inset)
            }
        }
    }

    private func findTabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar {
            return bar
        }
        for sub in view.subviews {
            if let found = findTabBar(in: sub) {
                return found
            }
        }
        return nil
    }
}

struct GlobalAudioPlayerOverlay: View {
    let bottomInset: CGFloat
    @ObservedObject private var player = AudioPlayerService.shared
    @StateObject private var keyboard = AudioKeyboardObserver()
    @State private var dragOffset: CGFloat = 0
    @State private var measuredTabBarInset: CGFloat = 0

    private let miniPlayerHeight: CGFloat = 52
    private let tabBarBaseHeight: CGFloat = 49

    private var isIOS26OrNewer: Bool {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return true
        }
#endif
        return false
    }

    var body: some View {
        GeometryReader { geometry in
            if !player.isOverlayHidden, let track = player.currentTrack {
                let globalFrame = geometry.frame(in: .global)
                let keyboardOverlap = keyboard.endFrame.isNull
                    ? CGFloat(0)
                    : max(0, globalFrame.maxY - keyboard.endFrame.minY)
                let effectiveTabBarInset: CGFloat = {
                    if measuredTabBarInset > 0 {
                        return measuredTabBarInset
                    }
                    let baseBarHeight: CGFloat = isIOS26OrNewer ? 128 : tabBarBaseHeight
                    return baseBarHeight + bottomInset
                }()
                let dockInset = keyboardOverlap > 0
                    ? keyboardOverlap
                    : effectiveTabBarInset
                let floatGap: CGFloat = keyboardOverlap > 0 ? 0 : (isIOS26OrNewer ? 8 : 0)
                let collapsedOffset = max(
                    0,
                    geometry.size.height - dockInset - miniPlayerHeight - floatGap
                )
                let baseOffset = player.isExpanded ? 0 : collapsedOffset
                let sheetOffset = min(collapsedOffset, max(0, baseOffset + dragOffset))
                let expansionProgress = collapsedOffset > 0
                    ? 1 - (sheetOffset / collapsedOffset)
                    : 1

                AudioPlayerSheet(
                    track: track,
                    expansionProgress: expansionProgress,
                    bottomInset: bottomInset,
                    miniPlayerHeight: miniPlayerHeight,
                    isIOS26: isIOS26OrNewer,
                    screenWidth: geometry.size.width,
                    dragOffset: $dragOffset,
                    collapsedOffset: collapsedOffset,
                    onExpand: expandPlayer,
                    onCollapse: collapsePlayer
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(y: sheetOffset)
            }
        }
        .overlay(
            TabBarAccessor(tabBarTopInset: $measuredTabBarInset)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false),
            alignment: .bottomLeading
        )
        .ignoresSafeArea()
        .allowsHitTesting(player.currentTrack != nil)
    }

    private func expandPlayer() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
            dragOffset = 0
            player.isExpanded = true
        }
    }

    private func collapsePlayer() {
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
            dragOffset = 0
            player.isExpanded = false
        }
    }
}

private struct PlayerDragDismissModifier: ViewModifier {
    @ObservedObject private var player = AudioPlayerService.shared
    @Binding var dragOffset: CGFloat
    let collapsedOffset: CGFloat

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .onChanged { value in
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }

                    if player.isExpanded {
                        dragOffset = min(collapsedOffset, max(0, value.translation.height))
                    } else {
                        dragOffset = max(-collapsedOffset, min(0, value.translation.height))
                    }
                }
                .onEnded { value in
                    let vertical = value.translation.height
                    let predicted = value.predictedEndTranslation.height
                    let isVertical = abs(vertical) > abs(value.translation.width)

                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
                        if isVertical {
                            if player.isExpanded {
                                if vertical > 70 || predicted > 130 {
                                    player.isExpanded = false
                                }
                            } else if vertical < -45 || predicted < -90 {
                                player.isExpanded = true
                            }
                        }
                        dragOffset = 0
                    }
                }
        )
    }
}

extension View {
    fileprivate func playerDragDismiss(dragOffset: Binding<CGFloat>, collapsedOffset: CGFloat) -> some View {
        modifier(PlayerDragDismissModifier(dragOffset: dragOffset, collapsedOffset: collapsedOffset))
    }
}

private struct AudioPlayerSheet: View {
    let track: AudioTrack
    let expansionProgress: CGFloat
    let bottomInset: CGFloat
    let miniPlayerHeight: CGFloat
    let isIOS26: Bool
    var screenWidth: CGFloat = UIScreen.main.bounds.width
    @Binding var dragOffset: CGFloat
    let collapsedOffset: CGFloat
    let onExpand: () -> Void
    let onCollapse: () -> Void

    @ObservedObject private var player = AudioPlayerService.shared

    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isSwitchingTrack: Bool = false

    private var progress: CGFloat {
        min(1, max(0, expansionProgress))
    }

    private var miniOpacity: Double {
        Double(min(1, max(0, 1 - progress * 2.2)))
    }

    private var expandedOpacity: Double {
        Double(min(1, max(0, (progress - 0.08) / 0.92)))
    }

    private var cardCornerRadius: CGFloat {
        let maxRadius: CGFloat = isIOS26 ? 18 : 0
        return (1 - progress) * maxRadius
    }

    private var cardHorizontalMargin: CGFloat {
        let maxMargin: CGFloat = isIOS26 ? 20 : 0
        return (1 - progress) * maxMargin
    }

    @ViewBuilder
    private var miniPlayerCard: some View {
        let current = player.currentTrack ?? track

#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            ZStack(alignment: .bottom) {
                MiniAudioPlayerView(
                    track: current,
                    isIOS26: true,
                    height: miniPlayerHeight
                )

                if player.duration > 0 {
                    MiniPlayerProgressBar(
                        duration: player.duration,
                        currentTime: player.currentTime,
                        isIOS26: true,
                        cornerRadius: cardCornerRadius
                    )
                }
            }
            .frame(height: miniPlayerHeight)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(
                    cornerRadius: cardCornerRadius,
                    style: .continuous
                )
            )
            .padding(.horizontal, cardHorizontalMargin)
            .offset(x: horizontalDragOffset)
        } else {
            classicMiniPlayerCard(current)
        }
#else
        classicMiniPlayerCard(current)
#endif
    }

    private func classicMiniPlayerCard(_ current: AudioTrack) -> some View {
        ZStack(alignment: .bottom) {
            ClassicMiniPlayerBackground()

            MiniAudioPlayerView(
                track: current,
                isIOS26: false,
                height: miniPlayerHeight
            )
            .offset(x: horizontalDragOffset)

            if player.duration > 0 {
                MiniPlayerProgressBar(
                    duration: player.duration,
                    currentTime: player.currentTime,
                    isIOS26: false,
                    cornerRadius: cardCornerRadius
                )
            }
        }
        .frame(height: miniPlayerHeight)
        .padding(.horizontal, cardHorizontalMargin)
        .clipped()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                Color(.systemBackground)
                    .opacity(expandedOpacity)

                Capsule()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 38, height: 5)
                    .padding(.top, 44)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(expandedOpacity)

                if miniOpacity > 0.001 {
                    miniPlayerCard
                        .opacity(miniOpacity)
                        .simultaneousGesture(horizontalSwipeGesture)
                }
            }
            .frame(height: miniPlayerHeight)
            .contentShape(Rectangle())
            .playerDragDismiss(dragOffset: $dragOffset, collapsedOffset: collapsedOffset)
            .onTapGesture {
                if progress < 0.5 {
                    onExpand()
                }
            }

            ExpandedAudioPlayerView(
                track: player.currentTrack ?? track,
                bottomInset: bottomInset,
                dragOffset: $dragOffset,
                collapsedOffset: collapsedOffset
            )
                .opacity(expandedOpacity)
                .allowsHitTesting(player.isExpanded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(.systemBackground)
                .opacity(expandedOpacity)
                .allowsHitTesting(player.isExpanded)
        )
    }

    private var horizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard progress < 0.1, !isSwitchingTrack else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                horizontalDragOffset = value.translation.width
            }
            .onEnded { value in
                guard progress < 0.1, !isSwitchingTrack else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.82)) {
                        horizontalDragOffset = 0
                    }
                    return
                }

                let horizontal = value.translation.width
                let predicted = value.predictedEndTranslation.width

                if horizontal < -35 || predicted < -70 {
                    triggerTrackSwitch(toNext: true)
                } else if horizontal > 35 || predicted > 70 {
                    triggerTrackSwitch(toNext: false)
                } else {
                    withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.82)) {
                        horizontalDragOffset = 0
                    }
                }
            }
    }

    private func triggerTrackSwitch(toNext: Bool) {
        guard !isSwitchingTrack else { return }
        isSwitchingTrack = true
        HapticManager.impact(.medium)

        let travelDistance = screenWidth > 0 ? screenWidth : 420
        let exitOffset = toNext ? -travelDistance : travelDistance
        let enterOffset = toNext ? travelDistance : -travelDistance

        withAnimation(.easeOut(duration: 0.16)) {
            horizontalDragOffset = exitOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if toNext {
                player.next(loopAtEnd: true)
            } else {
                player.previous(forcePrevious: true)
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                horizontalDragOffset = enterOffset
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    horizontalDragOffset = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                    isSwitchingTrack = false
                }
            }
        }
    }
}

private struct ClassicMiniPlayerBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(.bar)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(.separator).opacity(colorScheme == .dark ? 0.35 : 0.45))
                    .frame(height: 0.5)
            }
    }
}

private struct MiniPlayerProgressBar: View {
    let duration: Double
    let currentTime: Double
    let isIOS26: Bool
    let cornerRadius: CGFloat

    private var progressRatio: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, currentTime / duration)))
    }

    var body: some View {
        GeometryReader { geometry in
            let barHeight: CGFloat = isIOS26 ? 2.5 : 2.0
            let fillWidth = max(0, geometry.size.width * progressRatio)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(
                        isIOS26
                            ? Color.primary.opacity(0.08)
                            : Color(.separator).opacity(0.25)
                    )
                    .frame(height: barHeight)

                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: fillWidth, height: barHeight)
            }
            .frame(height: barHeight)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct MiniPlayerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct MiniAudioPlayerView: View {
    let track: AudioTrack
    let isIOS26: Bool
    let height: CGFloat
    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var membership = AudioLibraryMembership.shared

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                let artworkSize: CGFloat = height - 16 // 36 pt when height is 52
                let artworkRadius: CGFloat = isIOS26 ? 7 : 6

                AudioArtworkView(track: track, cornerRadius: artworkRadius)
                    .frame(width: artworkSize, height: artworkSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: artworkRadius, style: .continuous)
                            .stroke(
                                isIOS26
                                    ? Color.white.opacity(0.18)
                                    : Color.clear,
                                lineWidth: 0.5
                            )
                    )
                    .shadow(
                        color: isIOS26
                            ? Color.black.opacity(0.18)
                            : Color.black.opacity(0.08),
                        radius: isIOS26 ? 3 : 2,
                        y: isIOS26 ? 1.5 : 1
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Button(action: {
                HapticManager.impact(.light)
                membership.toggle(track)
            }) {
                Group {
                    if membership.isPending(track) {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: membership.isAdded(track) ? "checkmark" : "plus")
                            .font(.system(size: isIOS26 ? 16 : 15, weight: .semibold))
                    }
                }
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(MiniPlayerButtonStyle())
            .disabled(!membership.canMutate(track) || membership.isPending(track))
            .foregroundColor(membership.canMutate(track) ? .appAccent : .secondary)

            if player.isPreparing {
                ProgressView()
                    .frame(width: 32, height: 32)
            } else {
                Button(action: {
                    HapticManager.impact(.light)
                    player.togglePlayPause()
                }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isIOS26 ? 16 : 15, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MiniPlayerButtonStyle())
            }
        }
        .padding(.horizontal, isIOS26 ? 12 : 16)
        .frame(height: height)
        .contentShape(Rectangle())
    }
}

private struct ExpandedAudioPlayerView: View {
    let track: AudioTrack
    let bottomInset: CGFloat
    @Binding var dragOffset: CGFloat
    let collapsedOffset: CGFloat

    @State private var selectedPage = 0
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var dragAxis: DragAxis = .none

    private enum DragAxis {
        case none
        case horizontal
        case vertical
    }

    private var showQueue: Bool {
        selectedPage == 1
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .bottom) {
                // Page 0: Controls
                ExpandedAudioPlayerControlsView(track: track)
                    .frame(width: width, height: height)
                    .offset(x: selectedPage == 0 ? horizontalDragOffset : -width + horizontalDragOffset)
                    .gesture(page0Gesture(width: width))

                // Page 1: Queue
                AudioPlaybackQueueView(
                    dragOffset: $dragOffset,
                    collapsedOffset: collapsedOffset,
                    horizontalDragOffset: $horizontalDragOffset,
                    selectedPage: $selectedPage,
                    screenWidth: width
                )
                .frame(width: width, height: height)
                .offset(x: selectedPage == 1 ? horizontalDragOffset : width + horizontalDragOffset)
                .allowsHitTesting(selectedPage == 1)

                AudioPlayerBottomBar(
                    showQueue: showQueue,
                    bottomInset: bottomInset,
                    selectPlayer: { selectPage(0) },
                    selectQueue: { selectPage(1) }
                )
                .playerDragDismiss(dragOffset: $dragOffset, collapsedOffset: collapsedOffset)
            }
            .clipped()
            .background(Color(.systemBackground))
        }
    }

    private func selectPage(_ page: Int) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            selectedPage = page
            horizontalDragOffset = 0
        }
    }

    private func page0Gesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height

                if dragAxis == .none {
                    if abs(dx) > abs(dy) {
                        dragAxis = .horizontal
                    } else if dy > 0 {
                        dragAxis = .vertical
                    }
                }

                switch dragAxis {
                case .horizontal:
                    if dx < 0 {
                        horizontalDragOffset = max(-width, dx)
                    } else {
                        horizontalDragOffset = min(30, dx * 0.2)
                    }
                    dragOffset = 0
                case .vertical:
                    if dy > 0 {
                        dragOffset = min(collapsedOffset, dy)
                    } else {
                        dragOffset = max(-20, dy * 0.2)
                    }
                    horizontalDragOffset = 0
                case .none:
                    break
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let predictedX = value.predictedEndTranslation.width
                let predictedY = value.predictedEndTranslation.height
                let activeAxis = dragAxis
                dragAxis = .none

                switch activeAxis {
                case .horizontal:
                    if dx < -45 || predictedX < -90 {
                        HapticManager.impact(.light)
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            selectedPage = 1
                            horizontalDragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            horizontalDragOffset = 0
                        }
                    }
                case .vertical:
                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
                        if dy > 70 || predictedY > 130 {
                            AudioPlayerService.shared.isExpanded = false
                        }
                        dragOffset = 0
                    }
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        horizontalDragOffset = 0
                    }
                case .none:
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        horizontalDragOffset = 0
                    }
                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

private struct ExpandedAudioPlayerControlsView: View {
    let track: AudioTrack
    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var membership = AudioLibraryMembership.shared

    private var currentTrack: AudioTrack {
        player.currentTrack ?? track
    }

    var body: some View {
        GeometryReader { geometry in
            let artworkSize = min(
                geometry.size.width - 48,
                max(170, min(340, geometry.size.height * 0.42))
            )

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                AudioArtworkView(track: currentTrack, cornerRadius: 16)
                    .frame(width: artworkSize, height: artworkSize)
                    .shadow(color: Color.black.opacity(0.14), radius: 14, y: 7)

                Spacer(minLength: 14)

                VStack(spacing: 4) {
                    Text(currentTrack.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(currentTrack.artist)
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 28)

                VStack(spacing: 5) {
                    Slider(
                        value: Binding(
                            get: { min(player.currentTime, max(player.duration, 0.01)) },
                            set: { player.seek(to: $0) }
                        ),
                        in: 0...max(player.duration, 0.01)
                    )
                    .tint(.appAccent)

                    HStack {
                        Text(timeString(player.currentTime))
                        Spacer()
                        Text("-\(timeString(max(0, player.duration - player.currentTime)))")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 30)
                .padding(.top, 18)

                ZStack {
                    HStack(spacing: geometry.size.width < 350 ? 16 : 26) {
                        Button(action: { player.previous(forcePrevious: true) }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 28))
                                .frame(width: 46, height: 46)
                        }

                        Button(action: { player.togglePlayPause() }) {
                            Group {
                                if player.isPreparing {
                                    ProgressView()
                                        .scaleEffect(1.15)
                                } else {
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 34, weight: .semibold))
                                        .offset(x: player.isPlaying ? 0 : 2)
                                }
                            }
                            .frame(width: 56, height: 56)
                        }

                        Button(action: { player.next(loopAtEnd: true) }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 28))
                                .frame(width: 46, height: 46)
                        }
                    }

                    HStack {
                        Button(action: { membership.toggle(currentTrack) }) {
                            Group {
                                if membership.isPending(currentTrack) {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: membership.isAdded(currentTrack) ? "checkmark" : "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                }
                            }
                            .frame(width: 44, height: 44)
                        }
                        .disabled(!membership.canMutate(currentTrack) || membership.isPending(currentTrack))
                        .foregroundColor(membership.canMutate(currentTrack) ? .appAccent : .secondary)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.primary)
                .padding(.top, 12)

                Spacer(minLength: 82)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct AudioPlaybackQueueView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Binding var dragOffset: CGFloat
    let collapsedOffset: CGFloat
    @Binding var horizontalDragOffset: CGFloat
    @Binding var selectedPage: Int
    let screenWidth: CGFloat

    @State private var queueDragAxis: DragAxis = .none

    private enum DragAxis {
        case none
        case horizontal
        case vertical
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Очередь воспроизведения")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text(player.shuffleEnabled ? "Перемешанный порядок" : "Следующие треки")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(queueHeaderGesture)

            if player.upcomingQueue.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 34))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("Очередь пуста")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(queueHeaderGesture)
                .padding(.bottom, 76)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(player.upcomingQueue.prefix(150)) { entry in
                            HStack(spacing: 12) {
                                AudioArtworkView(track: entry.track, cornerRadius: 8)
                                    .frame(width: 48, height: 48)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.track.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(entry.track.artist)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                Text(entry.track.duration)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard horizontalDragOffset == 0 else { return }
                                HapticManager.impact(.light)
                                player.playQueueItem(at: entry.queueIndex)
                            }

                            SectionSeparator()
                                .padding(.leading, 80)
                        }
                    }
                    .padding(.bottom, 86)
                }
                .simultaneousGesture(queueSwipeBackGesture)
                .overlay(
                    Color.clear
                        .frame(width: 48)
                        .contentShape(Rectangle())
                        .gesture(queueLeadingEdgeGesture),
                    alignment: .leading
                )
            }
        }
        .background(Color(.systemBackground))
    }

    private var queueSwipeBackGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height

                guard abs(dx) > abs(dy) else { return }

                if dx > 0 {
                    horizontalDragOffset = min(screenWidth, dx)
                } else {
                    horizontalDragOffset = max(-30, dx * 0.2)
                }
                dragOffset = 0
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let predictedX = value.predictedEndTranslation.width

                guard abs(dx) > abs(dy) else {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        horizontalDragOffset = 0
                    }
                    return
                }

                if dx > 40 || predictedX > 80 {
                    HapticManager.impact(.light)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedPage = 0
                        horizontalDragOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        horizontalDragOffset = 0
                    }
                }
            }
    }

    private var queueHeaderGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height

                if queueDragAxis == .none {
                    if abs(dx) > abs(dy) {
                        queueDragAxis = .horizontal
                    } else if dy > 0 {
                        queueDragAxis = .vertical
                    }
                }

                switch queueDragAxis {
                case .horizontal:
                    if dx > 0 {
                        horizontalDragOffset = min(screenWidth, dx)
                    } else {
                        horizontalDragOffset = max(-30, dx * 0.2)
                    }
                    dragOffset = 0
                case .vertical:
                    if dy > 0 {
                        dragOffset = min(collapsedOffset, dy)
                    } else {
                        dragOffset = max(-20, dy * 0.2)
                    }
                    horizontalDragOffset = 0
                case .none:
                    break
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let predictedX = value.predictedEndTranslation.width
                let predictedY = value.predictedEndTranslation.height
                let activeAxis = queueDragAxis
                queueDragAxis = .none

                switch activeAxis {
                case .horizontal:
                    if dx > 45 || predictedX > 90 {
                        HapticManager.impact(.light)
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            selectedPage = 0
                            horizontalDragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            horizontalDragOffset = 0
                        }
                    }
                case .vertical:
                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
                        if dy > 70 || predictedY > 130 {
                            player.isExpanded = false
                        }
                        dragOffset = 0
                    }
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        horizontalDragOffset = 0
                    }
                case .none:
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        horizontalDragOffset = 0
                    }
                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private var queueLeadingEdgeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                let dx = value.translation.width
                if dx > 0 {
                    horizontalDragOffset = min(screenWidth, dx)
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let predictedX = value.predictedEndTranslation.width

                if dx > 40 || predictedX > 80 {
                    HapticManager.impact(.light)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedPage = 0
                        horizontalDragOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        horizontalDragOffset = 0
                    }
                }
            }
    }
}

private struct AudioPlayerBottomBar: View {
    let showQueue: Bool
    let bottomInset: CGFloat
    let selectPlayer: () -> Void
    let selectQueue: () -> Void

    @ObservedObject private var player = AudioPlayerService.shared

    var body: some View {
        HStack(spacing: 16) {
            Button(action: { player.toggleShuffle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(player.shuffleEnabled ? .appAccent : .secondary)
                    .frame(width: 52, height: 44)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            HStack(spacing: 18) {
                Button(action: selectPlayer) {
                    Circle()
                        .fill(showQueue ? Color(.tertiaryLabel) : Color.appAccent)
                        .frame(width: 8, height: 8)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: selectQueue) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(showQueue ? .appAccent : Color(.tertiaryLabel))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            Button(action: { player.cycleRepeatMode() }) {
                Image(systemName: player.repeatMode.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(player.repeatMode == .off ? .secondary : .appAccent)
                    .frame(width: 52, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 30)
        .padding(.bottom, max(12, bottomInset + 6))
        .background(
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 76)
            .allowsHitTesting(false),
            alignment: .bottom
        )
    }
}

struct AudioListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AudioListView()
                .environmentObject(AuthService.shared)
        }
    }
}
