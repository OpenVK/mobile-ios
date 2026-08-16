//
//  AlbumsListViewModel.swift
//  OpenVK for iOS
//

import SwiftUI

class AlbumsListViewModel: ObservableObject {
    @Published var albums: [PhotoAlbum] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let ownerID: Int
    
    init(ownerID: Int) {
        self.ownerID = ownerID
    }
    
    func load(completion: (() -> Void)? = nil) {
        guard !isLoading else {
            completion?()
            return
        }
        isLoading = albums.isEmpty
        errorMessage = nil
        
        ProfileService.shared.fetchAlbums(ownerID: ownerID) { [weak self] result in
            guard let self = self else {
                completion?()
                return
            }
            self.isLoading = false
            switch result {
            case .success(let albums):
                self.albums = albums
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
            completion?()
        }
    }
}
