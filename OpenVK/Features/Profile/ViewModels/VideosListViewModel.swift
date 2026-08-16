//
//  VideosListViewModel.swift
//  OpenVK for iOS
//

import SwiftUI

class VideosListViewModel: ObservableObject {
    @Published var videos: [Video] = []
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
        isLoading = videos.isEmpty
        errorMessage = nil
        
        ProfileService.shared.fetchVideos(ownerID: ownerID) { [weak self] result in
            guard let self = self else {
                completion?()
                return
            }
            self.isLoading = false
            switch result {
            case .success(let videos):
                self.videos = videos
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
            completion?()
        }
    }
}
