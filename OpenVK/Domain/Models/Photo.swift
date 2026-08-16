//
//  Photo.swift
//  OpenVK for iOS
//
//  Модель фотографии.
//

import SwiftUI

struct Photo: Identifiable {
    let id: UUID
    let vkID: Int?
    let ownerID: Int?
    let imageURL: URL?
    let systemName: String
    let color: Color
    let likesCount: Int
    let commentsCount: Int
    let repostsCount: Int
    let isLiked: Bool

    init(id: UUID = UUID(),
         vkID: Int? = nil,
         ownerID: Int? = nil,
         imageURL: URL? = nil,
         systemName: String = "photo",
         color: Color = .appAccent,
         likesCount: Int = 0,
         commentsCount: Int = 0,
         repostsCount: Int = 0,
         isLiked: Bool = false) {
        self.id = id
        self.vkID = vkID
        self.ownerID = ownerID
        self.imageURL = imageURL
        self.systemName = systemName
        self.color = color
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.repostsCount = repostsCount
        self.isLiked = isLiked
    }
}
