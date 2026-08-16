//
//  FeedViewModel.swift
//  OpenVK for iOS
//

import Foundation

enum FeedType: String, CaseIterable, Identifiable {
    case subscriptions = "Мои новости"
    case all = "Все новости"

    var id: String { rawValue }
}

final class FeedViewModel: ObservableObject {

    @Published private(set) var posts: [Post] = []
    @Published private(set) var filteredPosts: [Post] = []
    
    @Published var feedType: FeedType = {
        if let saved = UserDefaults.standard.string(forKey: "openvk.feed_type"),
           let type = FeedType(rawValue: saved) {
            return type
        }
        return .subscriptions
    }() {
        didSet {
            UserDefaults.standard.set(feedType.rawValue, forKey: "openvk.feed_type")
            refresh()
        }
    }

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var canLoadMore: Bool = true
    @Published var errorMessage: String?
    @Published var selectedPost: Post? = nil
    @Published var showDetail: Bool = false

    private var nextFrom: String? = nil
    private var lastTriggeredPostID: Int? = nil
    private let service: FeedServiceProtocol
    private var accountObserver: NSObjectProtocol?

    init(service: FeedServiceProtocol = FeedService.shared) {
        self.service = service
        accountObserver = NotificationCenter.default.addObserver(
            forName: .openvkAccountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let accountObserver = accountObserver {
            NotificationCenter.default.removeObserver(accountObserver)
        }
    }

    func load() {
        if posts.isEmpty {
            refresh()
        }
    }

    func refreshAsync(clearPosts: Bool = false) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            refresh(clearPosts: clearPosts) {
                continuation.resume()
            }
        }
    }

    func refresh(clearPosts: Bool = true, completion: (() -> Void)? = nil) {
        if clearPosts {
            posts = []
            filteredPosts = []
            isLoading = true
        }
        errorMessage = nil
        nextFrom = nil
        lastTriggeredPostID = nil
        canLoadMore = true
        
        let isGlobal = (feedType == .all)
        service.fetchFeed(isGlobal: isGlobal, startFrom: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion?()
                    return
                }
                self.isLoading = false
                switch result {
                case .success(let data):
                    self.posts = data.posts
                    self.filteredPosts = data.posts
                    self.nextFrom = data.nextFrom
                    if data.posts.isEmpty {
                        self.canLoadMore = false
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                completion?()
            }
        }
    }

    func loadNextPage() {
        guard !isLoading && !isLoadingMore && canLoadMore else { return }
        
        let cursor = nextFrom ?? (posts.last?.vkID != nil ? "\(posts.last?.vkID ?? 0)" : nil)
        guard let validCursor = cursor else { return }
        
        if let lastPostID = posts.last?.vkID {
            if lastTriggeredPostID == lastPostID {
                return
            }
            lastTriggeredPostID = lastPostID
        }
        
        isLoadingMore = true
        let isGlobal = (feedType == .all)
        service.fetchFeed(isGlobal: isGlobal, startFrom: validCursor) { [weak self] result in
            guard let self = self else { return }
            self.isLoadingMore = false
            switch result {
            case .success(let data):
                if data.posts.isEmpty {
                    self.canLoadMore = false
                } else {
                    self.posts.append(contentsOf: data.posts)
                    self.filteredPosts = self.posts
                    self.nextFrom = data.nextFrom
                }
            case .failure(let error):
                self.lastTriggeredPostID = nil
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func toggleLike(for post: Post) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }

        guard post.vkID != nil, post.author.uid != nil else {
            posts[idx].isLiked.toggle()
            posts[idx].likes = max(0, posts[idx].likes + (posts[idx].isLiked ? 1 : -1))
            filteredPosts = posts
            return
        }

        let previous = posts[idx]
        posts[idx].isLiked.toggle()
        posts[idx].likes = max(0, posts[idx].likes + (posts[idx].isLiked ? 1 : -1))
        filteredPosts = posts

        service.like(post: previous) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let updated):
                if let idx = self.posts.firstIndex(where: { $0.id == post.id }) {
                    self.posts[idx] = updated
                    self.filteredPosts = self.posts
                }
            case .failure:
                if let idx = self.posts.firstIndex(where: { $0.id == post.id }) {
                    self.posts[idx] = previous
                    self.filteredPosts = self.posts
                }
            }
        }
    }

    func updateRepostsCount(for post: Post, count: Int) {
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx].reposts = count
            filteredPosts = posts
        }
    }

    func addPost(text: String) {
        service.createPost(text: text, ownerID: nil, attachments: nil, explicit: false, fromGroup: false, signed: false, targetUser: nil) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let post):
                self.posts.insert(post, at: 0)
                self.filteredPosts = self.posts
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
