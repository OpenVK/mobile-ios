//
//  Comment.swift
//  OpenVK for iOS
//


import Foundation

struct Comment: Identifiable, Hashable {
    let id: Int
    let postId: Int
    let fromId: Int
    let ownerId: Int
    let author: User
    let text: String
    let date: Date
    let likesCount: Int
    var isLiked: Bool
    let attachments: [Attachment]

    var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct VKCommentsResponse: Decodable {
    let count: Int
    let items: [VKCommentItem]
    let profiles: [VKProfile]?
    let groups: [VKGroup]?
    let currentLevelCount: Int?
    let canPost: Bool?
}

struct VKCommentItem: Decodable {
    let id: Int
    let fromId: Int
    let date: Double
    let text: String
    let postId: Int?
    let ownerId: Int?
    let likes: VKCommentLikes?
    let attachments: [VKAttachment]?
}

struct VKCommentLikes: Decodable {
    let count: Int
    let userLikes: Int
    let canLike: Int?
}

struct VKCreateCommentResponse: Decodable {
    let commentId: Int
}

struct VKDefaultResponse: Decodable {
    let response: Int
}
