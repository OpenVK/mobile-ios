//
//  SearchViewModel.swift
//  OpenVK for iOS
//

import Foundation
import Combine

final class SearchViewModel: ObservableObject {

    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }
    @Published private(set) var users: [User] = []
    @Published private(set) var posts: [Post] = []

    private let service: SearchServiceProtocol
    private var pendingWorkItem: DispatchWorkItem?

    init(service: SearchServiceProtocol = SearchService.shared) {
        self.service = service
    }

    private func scheduleSearch() {
        pendingWorkItem?.cancel()
        let currentQuery = query
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSearch(currentQuery)
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func performSearch(_ q: String) {
        service.searchUsers(query: q) { [weak self] users in
            self?.users = users
        }
        service.searchPosts(query: q) { [weak self] posts in
            self?.posts = posts
        }
    }
}
