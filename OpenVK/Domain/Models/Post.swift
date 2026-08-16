//
//  Post.swift
//  OpenVK for iOS
//
//  Модель поста.
//

import Foundation

struct VKLikesInfo: Decodable, Hashable {
    let count: Int?
    let userLikes: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let countInt = try? container.decode(Int.self) {
            self.count = countInt
            self.userLikes = 0
        } else if let dict = try? container.decode(RawLikes.self) {
            self.count = dict.count
            self.userLikes = dict.userLikes
        } else {
            self.count = nil
            self.userLikes = nil
        }
    }

    private struct RawLikes: Decodable {
        let count: Int?
        let userLikes: Int?
    }
}

struct VKCommentsInfo: Decodable, Hashable {
    let count: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let countInt = try? container.decode(Int.self) {
            self.count = countInt
        } else if let dict = try? container.decode(RawComments.self) {
            self.count = dict.count
        } else {
            self.count = nil
        }
    }

    private struct RawComments: Decodable {
        let count: Int?
    }
}

struct VKRepostsInfo: Decodable, Hashable {
    let count: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let countInt = try? container.decode(Int.self) {
            self.count = countInt
        } else if let dict = try? container.decode(RawReposts.self) {
            self.count = dict.count
        } else {
            self.count = nil
        }
    }

    private struct RawReposts: Decodable {
        let count: Int?
    }
}

struct Post: Identifiable, Hashable {
    let id: UUID
    let vkID: Int?
    let ownerID: Int?
    let author: User
    let wallOwner: User?
    let platform: String?
    let timeAgo: String
    let text: String
    let hasImage: Bool
    let attachments: [Attachment]
    var likes: Int
    var comments: Int
    var reposts: Int
    var isLiked: Bool
    let copyHistory: [Post]
    let isExplicit: Bool

    var isOnAlienWall: Bool { wallOwner != nil }

    init(id: UUID = UUID(),
         vkID: Int? = nil,
         ownerID: Int? = nil,
         author: User,
         wallOwner: User? = nil,
         platform: String? = nil,
         timeAgo: String,
         text: String,
         hasImage: Bool = false,
         attachments: [Attachment] = [],
         likes: Int = 0,
         comments: Int = 0,
         reposts: Int = 0,
         isLiked: Bool = false,
         copyHistory: [Post] = [],
         isExplicit: Bool = false) {
        self.id = id
        self.vkID = vkID
        self.ownerID = ownerID
        self.author = author
        self.wallOwner = wallOwner
        self.platform = platform
        self.timeAgo = timeAgo
        self.text = text

        let hasImg = hasImage || attachments.contains(where: {
            if case .image = $0 { return true }
            if case .remoteImage = $0 { return true }
            return false
        })
        self.hasImage = hasImg
        self.attachments = attachments.isEmpty && hasImg ? [.image(systemName: "photo")] : attachments
        self.likes = likes
        self.comments = comments
        self.reposts = reposts
        self.isLiked = isLiked
        self.copyHistory = copyHistory
        self.isExplicit = isExplicit
    }
}

enum PostPlatform: String {
    case android, iphone, wphone, mobile, api, web

    var assetName: String? {
        switch self {
        case .android: return "android"
        case .wphone:  return "wphone"
        default:       return nil
        }
    }

    var iconName: String {
        switch self {
        case .android: return "phone.fill"
        case .iphone:  return "applelogo"
        case .wphone:  return "ipad"
        case .mobile:  return "phone.fill"
        case .api:     return "chevron.left.forwardslash.chevron.right"
        case .web:     return "globe"
        }
    }
}
