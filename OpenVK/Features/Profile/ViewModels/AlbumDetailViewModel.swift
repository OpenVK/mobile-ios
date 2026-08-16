//
//  AlbumDetailViewModel.swift
//  OpenVK for iOS
//

import SwiftUI

class AlbumDetailViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    let album: PhotoAlbum
    
    init(album: PhotoAlbum) {
        self.album = album
    }
    
    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        ProfileService.shared.fetchAlbumPhotos(ownerID: album.ownerID, albumID: album.vkID) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success(let photos):
                self.photos = photos
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
