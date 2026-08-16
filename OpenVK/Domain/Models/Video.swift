//
//  Video.swift
//  OpenVK for iOS
//
//  Модель видеозаписи.
//

import SwiftUI

struct Video: Identifiable {
    let id: UUID
    let vkID: Int?
    let ownerID: Int?
    let title: String
    let duration: String
    let color: Color
    let systemName: String
    let imageURL: URL?
    let playerURL: URL?
    let files: [String: String]?
    let likesCount: Int
    let commentsCount: Int
    let repostsCount: Int
    let isLiked: Bool

    init(id: UUID = UUID(),
         vkID: Int? = nil,
         ownerID: Int? = nil,
         title: String,
         duration: String,
         color: Color = .appAccent,
         systemName: String = "play.circle.fill",
         imageURL: URL? = nil,
         playerURL: URL? = nil,
         files: [String: String]? = nil,
         likesCount: Int = 0,
         commentsCount: Int = 0,
         repostsCount: Int = 0,
         isLiked: Bool = false) {
        self.id = id
        self.vkID = vkID
        self.ownerID = ownerID
        self.title = title
        self.duration = duration
        self.color = color
        self.systemName = systemName
        self.imageURL = imageURL
        self.playerURL = playerURL
        self.files = files
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.repostsCount = repostsCount
        self.isLiked = isLiked
    }
}
