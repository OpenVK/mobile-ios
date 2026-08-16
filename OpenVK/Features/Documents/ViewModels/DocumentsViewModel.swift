//
//  DocumentsViewModel.swift
//  OpenVK for iOS
//

import Foundation
import Combine

final class DocumentsViewModel: ObservableObject {

    @Published var searchQuery: String = "" {
        didSet {
            debouncedSearch()
        }
    }

    @Published private(set) var myDocuments: [AppDocument] = []
    @Published private(set) var localSearchResults: [AppDocument] = []
    @Published private(set) var globalSearchResults: [AppDocument] = []
    
    @Published private(set) var isLoadingMy: Bool = false
    @Published private(set) var isLoadingMoreMy: Bool = false
    @Published private(set) var hasMoreMy: Bool = true

    @Published private(set) var isGlobalSearching: Bool = false
    @Published private(set) var isLoadingMoreGlobal: Bool = false
    @Published private(set) var hasMoreGlobal: Bool = true
    
    @Published var errorMessage: String? = nil
    @Published var statusMessage: String? = nil

    private var myOffset = 0
    private var globalOffset = 0
    private let countPerPage = 30
    private var searchWorkItem: DispatchWorkItem? = nil

    private let service: DocumentsServiceProtocol

    init(service: DocumentsServiceProtocol = DocumentsService.shared) {
        self.service = service
    }

    var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadInitialData() {
        if myDocuments.isEmpty {
            fetchMyDocuments(reset: true)
        }
    }

    func refresh(completion: (() -> Void)? = nil) {
        if isSearching {
            performGlobalSearch(reset: true, completion: completion)
        } else {
            fetchMyDocuments(reset: true, completion: completion)
        }
    }

    func loadMoreMyDocuments() {
        guard !isLoadingMy && !isLoadingMoreMy && hasMoreMy && !isSearching else { return }
        fetchMyDocuments(reset: false)
    }

    func loadMoreGlobal() {
        guard !isGlobalSearching && !isLoadingMoreGlobal && hasMoreGlobal && isSearching else { return }
        performGlobalSearch(reset: false)
    }

    func addDocument(_ doc: AppDocument) {
        guard doc.ownerID != 0 else {
            self.errorMessage = "Этот документ приватный, его нельзя сохранить"
            return
        }

        service.addDocument(ownerID: doc.ownerID, docID: doc.id, accessKey: doc.accessKey) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.statusMessage = "Документ добавлен в ваши документы"
                    self.fetchMyDocuments(reset: true)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func deleteDocument(_ doc: AppDocument) {
        guard doc.isOwn else {
            self.errorMessage = "Вы можете удалять только свои личные документы"
            return
        }

        service.deleteDocument(ownerID: doc.ownerID, docID: doc.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.myDocuments.removeAll { $0.id == doc.id && $0.ownerID == doc.ownerID }
                    self.localSearchResults.removeAll { $0.id == doc.id && $0.ownerID == doc.ownerID }
                    self.globalSearchResults.removeAll { $0.id == doc.id && $0.ownerID == doc.ownerID }
                    self.statusMessage = "Документ удален"
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func debouncedSearch() {
        searchWorkItem?.cancel()

        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            localSearchResults = []
            globalSearchResults = []
            isGlobalSearching = false
            return
        }

        let query = trimmed.lowercased()
        localSearchResults = myDocuments.filter {
            $0.title.lowercased().contains(query) || $0.ext.lowercased().contains(query)
        }

        let item = DispatchWorkItem { [weak self] in
            self?.performGlobalSearch(reset: true)
        }
        searchWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    private func fetchMyDocuments(reset: Bool, completion: (() -> Void)? = nil) {
        if reset {
            myOffset = 0
            hasMoreMy = true
            isLoadingMy = true
        } else {
            isLoadingMoreMy = true
        }

        service.fetchMyDocuments(offset: myOffset, count: countPerPage) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion?()
                    return
                }
                self.isLoadingMy = false
                self.isLoadingMoreMy = false

                switch result {
                case .success(let items):
                    if reset {
                        self.myDocuments = items
                    } else {
                        self.myDocuments.append(contentsOf: items)
                    }
                    self.myOffset += items.count
                    self.hasMoreMy = items.count >= self.countPerPage
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                completion?()
            }
        }
    }

    private func performGlobalSearch(reset: Bool, completion: (() -> Void)? = nil) {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            completion?()
            return
        }

        if reset {
            globalOffset = 0
            hasMoreGlobal = true
            isGlobalSearching = true
        } else {
            isLoadingMoreGlobal = true
        }

        service.searchDocuments(query: query, searchOwn: 0, offset: globalOffset, count: countPerPage) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion?()
                    return
                }
                self.isGlobalSearching = false
                self.isLoadingMoreGlobal = false

                switch result {
                case .success(let items):
                    if reset {
                        self.globalSearchResults = items
                    } else {
                        self.globalSearchResults.append(contentsOf: items)
                    }
                    self.globalOffset += items.count
                    self.hasMoreGlobal = items.count >= self.countPerPage
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                completion?()
            }
        }
    }
}
