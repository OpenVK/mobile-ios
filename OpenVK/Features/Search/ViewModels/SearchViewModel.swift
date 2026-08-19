//
//  SearchViewModel.swift
//  OpenVK for iOS
//
//  Управление состоянием и поиск по всем категориям.
//

import Foundation
import Combine
import SwiftUI

enum SearchCategory: String, CaseIterable, Identifiable {
    case all = "Все"
    case users = "Люди"
    case groups = "Группы"
    case posts = "Записи"
    case videos = "Видео"
    case audios = "Музыка"
    case documents = "Документы"

    var id: String { rawValue }
    var title: String { rawValue }

    var iconName: String {
        switch self {
        case .all: return "sparkles"
        case .users: return "person.2"
        case .groups: return "person.3"
        case .posts: return "doc.text"
        case .videos: return "play.rectangle"
        case .audios: return "music.note"
        case .documents: return "doc.fill"
        }
    }
}

enum UserSortOption: Int, CaseIterable, Identifiable {
    case popular = 4
    case newest = 1
    case oldest = 0

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .popular: return "По рейтингу"
        case .newest: return "Сначала новые"
        case .oldest: return "Сначала старые"
        }
    }
}

enum GroupSortOption: Int, CaseIterable, Identifiable {
    case byMembers = 0
    case byAlphabet = 1

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .byMembers: return "По участникам"
        case .byAlphabet: return "По алфавиту"
        }
    }
}

enum VideoSortOption: Int, CaseIterable, Identifiable {
    case byDate = 0
    case byDuration = 1
    case byPopularity = 2

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .byDate: return "По дате добавления"
        case .byDuration: return "По длительности"
        case .byPopularity: return "По популярности"
        }
    }
}

enum AudioSortOption: Int, CaseIterable, Identifiable {
    case byPopularity = 2
    case byDate = 0
    case byDuration = 1

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .byPopularity: return "По популярности"
        case .byDate: return "По дате добавления"
        case .byDuration: return "По длительности"
        }
    }
}

enum DocTypeFilter: Int, CaseIterable, Identifiable {
    case all = 0
    case text = 1
    case archive = 2
    case gif = 3
    case image = 4
    case audio = 5
    case video = 6
    case book = 7
    case other = 8

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .all: return "Все форматы"
        case .text: return "Текстовые"
        case .archive: return "Архивы"
        case .gif: return "GIF"
        case .image: return "Изображения"
        case .audio: return "Аудио"
        case .video: return "Видео"
        case .book: return "Книги"
        case .other: return "Другое"
        }
    }
}

final class SearchViewModel: ObservableObject {

    @Published var query: String = "" {
        didSet {
            if query != oldValue {
                scheduleSearch()
            }
        }
    }
    
    @Published var selectedCategory: SearchCategory = .all {
        didSet {
            if selectedCategory != oldValue {
                performSearch(query, force: true)
            }
        }
    }

    @Published var userSort: UserSortOption = .popular {
        didSet { if selectedCategory == .users { performSearch(query, force: true) } }
    }
    @Published var userOnlyOnline: Bool = false {
        didSet { if selectedCategory == .users { performSearch(query, force: true) } }
    }

    @Published var groupSort: GroupSortOption = .byMembers {
        didSet { if selectedCategory == .groups { performSearch(query, force: true) } }
    }

    @Published var videoSort: VideoSortOption = .byDate {
        didSet { if selectedCategory == .videos { performSearch(query, force: true) } }
    }

    @Published var audioSort: AudioSortOption = .byPopularity {
        didSet { if selectedCategory == .audios { performSearch(query, force: true) } }
    }
    @Published var audioPerformerOnly: Bool = false {
        didSet { if selectedCategory == .audios { performSearch(query, force: true) } }
    }
    @Published var audioWithLyrics: Bool = false {
        didSet { if selectedCategory == .audios { performSearch(query, force: true) } }
    }

    @Published var docType: DocTypeFilter = .all {
        didSet { if selectedCategory == .documents { performSearch(query, force: true) } }
    }
    
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var allResults: SearchAllResults = SearchAllResults()
    @Published private(set) var users: [User] = []
    @Published private(set) var groups: [Community] = []
    @Published private(set) var posts: [Post] = []
    @Published private(set) var videos: [Video] = []
    @Published private(set) var audios: [AudioTrack] = []
    @Published private(set) var documents: [AppDocument] = []
    @Published var errorMessage: String? = nil

    private let service: SearchServiceProtocol
    private var pendingWorkItem: DispatchWorkItem?

    init(service: SearchServiceProtocol = SearchService.shared) {
        self.service = service
        performSearch("")
    }

    var isCurrentResultsEmpty: Bool {
        guard !isLoading else { return false }
        
        switch selectedCategory {
        case .all:
            return allResults.isEmpty
        case .users:
            return users.isEmpty
        case .groups:
            return groups.isEmpty
        case .posts:
            return posts.isEmpty
        case .videos:
            return videos.isEmpty
        case .audios:
            return audios.isEmpty
        case .documents:
            return documents.isEmpty
        }
    }

    var activeSortDescription: String {
        switch selectedCategory {
        case .all:
            return "По релевантности"
        case .users:
            return userOnlyOnline ? "\(userSort.title) • Онлайн" : userSort.title
        case .groups:
            return groupSort.title
        case .posts:
            return "Сначала новые"
        case .videos:
            return videoSort.title
        case .audios:
            if audioPerformerOnly {
                return "\(audioSort.title) • Исполнитель"
            } else if audioWithLyrics {
                return "\(audioSort.title) • С текстом"
            } else {
                return audioSort.title
            }
        case .documents:
            return docType.title
        }
    }

    func selectCategory(_ category: SearchCategory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            self.selectedCategory = category
        }
    }

    func clearQuery() {
        query = ""
        performSearch("")
    }

    private func scheduleSearch() {
        pendingWorkItem?.cancel()
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSearch(currentQuery)
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    func performSearch(_ q: String? = nil, force: Bool = false) {
        let currentQuery = (q ?? query).trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        errorMessage = nil

        switch selectedCategory {
        case .all:
            service.searchAll(query: currentQuery) { [weak self] results in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.allResults = results
                    self.isLoading = false
                }
            }
        case .users:
            service.searchUsers(
                query: currentQuery,
                sort: userSort.rawValue,
                onlyOnline: userOnlyOnline,
                offset: 0,
                count: 40
            ) { [weak self] fetched in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.users = fetched
                    self.isLoading = false
                }
            }
        case .groups:
            service.searchGroups(
                query: currentQuery,
                sort: groupSort.rawValue,
                offset: 0,
                count: 40
            ) { [weak self] fetched in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.groups = fetched
                    self.isLoading = false
                }
            }
        case .posts:
            service.searchPosts(query: currentQuery, count: 30, startFrom: nil) { [weak self] fetched in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.posts = fetched
                    self.isLoading = false
                }
            }
        case .videos:
            service.searchVideos(
                query: currentQuery,
                sort: videoSort.rawValue,
                offset: 0,
                count: 30
            ) { [weak self] fetched in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.videos = fetched
                    self.isLoading = false
                }
            }
        case .audios:
            service.searchAudios(
                query: currentQuery,
                sort: audioSort.rawValue,
                performerOnly: audioPerformerOnly,
                withLyrics: audioWithLyrics,
                offset: 0,
                count: 40
            ) { [weak self] fetched in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.audios = fetched
                    self.isLoading = false
                }
            }
        case .documents:
            service.searchDocuments(
                query: currentQuery,
                type: docType.rawValue,
                offset: 0,
                count: 40
            ) { [weak self] fetched in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.documents = fetched
                    self.isLoading = false
                }
            }
        }
    }

    func refresh() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            performSearch(query, force: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
}
