//
//  ProfileViewModel.swift
//  OpenVK for iOS
//

import Foundation

final class ProfileViewModel: ObservableObject {

    @Published private(set) var user: User
    @Published private(set) var wall: [Post] = []
    @Published private(set) var photos: [Photo] = []
    @Published private(set) var photoCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var isLoadingMoreWall: Bool = false
    @Published var errorMessage: String? = nil

    private var offset: Int = 0
    private var canLoadMore: Bool = true
    private var lastTriggeredPostID: Int? = nil
    private let service: ProfileServiceProtocol

    init(user: User = .current, service: ProfileServiceProtocol = ProfileService.shared) {
        self.user = user
        self.service = service
    }

    func load() {
        isLoading = true
        errorMessage = nil
        offset = 0
        canLoadMore = true
        lastTriggeredPostID = nil
        
        service.fetchProfile(username: user.username) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let fetchedUser):
                self.user = fetchedUser
                
                if let ownerID = fetchedUser.uid,
                   fetchedUser.accessStatus == .active {
                    self.loadWallAndPhotos(ownerID: ownerID)
                } else {
                    self.isLoading = false
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func loadWallAndPhotos(ownerID: Int) {
        let group = DispatchGroup()

        group.enter()
        service.fetchWall(ownerID: ownerID, offset: 0) { [weak self] result in
            guard let self = self else { return }
            if case .success(let posts) = result {
                self.wall = posts
                self.offset = posts.count
                if posts.count < 20 {
                    self.canLoadMore = false
                }
            }
            group.leave()
        }

        group.enter()
        service.fetchPhotos(ownerID: ownerID) { [weak self] result in
            if case .success(let fetchedPhotos) = result {
                self?.photos = fetchedPhotos
                self?.photoCount = fetchedPhotos.count
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }

    func loadMoreWall() {
        guard let ownerID = user.uid, !isLoading, !isLoadingMoreWall, canLoadMore else { return }
        
        if let lastPostID = wall.last?.vkID {
            if lastTriggeredPostID == lastPostID {
                return
            }
            lastTriggeredPostID = lastPostID
        }
        
        isLoadingMoreWall = true
        service.fetchWall(ownerID: ownerID, offset: offset) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoadingMoreWall = false
                switch result {
                case .success(let posts):
                    if posts.isEmpty {
                        self.canLoadMore = false
                    } else {
                        self.wall.append(contentsOf: posts)
                        self.offset += posts.count
                        if posts.count < 20 {
                            self.canLoadMore = false
                        }
                    }
                case .failure(let error):
                    print("Error loading more wall posts: \(error)")
                }
            }
        }
    }

    func like(post: Post) {
        guard let idx = wall.firstIndex(where: { $0.id == post.id }) else { return }

        guard post.vkID != nil, post.author.uid != nil else {
            wall[idx].isLiked.toggle()
            wall[idx].likes = max(0, wall[idx].likes + (wall[idx].isLiked ? 1 : -1))
            return
        }

        let previous = wall[idx]
        wall[idx].isLiked.toggle()
        wall[idx].likes = max(0, wall[idx].likes + (wall[idx].isLiked ? 1 : -1))

        FeedService.shared.like(post: previous) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let updated):
                if let idx = self.wall.firstIndex(where: { $0.id == post.id }) {
                    self.wall[idx] = updated
                }
            case .failure:
                if let idx = self.wall.firstIndex(where: { $0.id == post.id }) {
                    self.wall[idx] = previous
                }
            }
        }
    }

    func updateRepostsCount(for post: Post, count: Int) {
        if let idx = wall.firstIndex(where: { $0.id == post.id }) {
            wall[idx].reposts = count
        }
    }

    func insertPost(_ post: Post) {
        wall.insert(post, at: 0)
    }
}
