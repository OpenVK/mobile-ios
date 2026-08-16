//
//  PhotoAlbum.swift
//  OpenVK for iOS
//
//  Модель альбома фотографий.
//

import SwiftUI

struct PhotoAlbum: Identifiable {
    let id: UUID
    let vkID: Int
    let ownerID: Int
    let title: String
    let photos: [Photo]
    let coverURL: URL?
    let size: Int

    var count: Int { photos.isEmpty ? size : photos.count }

    var coverColor: Color { photos.first?.color ?? Color(.tertiarySystemFill) }
    var coverSystemName: String { photos.first?.systemName ?? "photo" }

    init(id: UUID = UUID(),
         vkID: Int = 0,
         ownerID: Int = 0,
         title: String,
         photos: [Photo] = [],
         coverURL: URL? = nil,
         size: Int = 0) {
        self.id = id
        self.vkID = vkID
        self.ownerID = ownerID
        self.title = title
        self.photos = photos
        self.coverURL = coverURL
        self.size = size
    }
}
