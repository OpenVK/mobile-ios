//
//  User.swift
//  OpenVK for iOS
//
//  Модель пользователя.
//

import Foundation

enum ProfileAccessStatus: Hashable {
    case active
    case deleted
    case banned(reason: String?)
    case blacklistedByThem
    case blacklistedByMe
    case privateProfile
}

struct User: Identifiable, Hashable, Codable {
    let id: UUID
    let uid: Int?
    let username: String
    let displayName: String
    let avatarURL: URL?
    let city: String?
    let isOnline: Bool
    let onlinePlatform: String? // "android", "iphone", "web" и т.п.
    let lastSeen: String?
    let isGroup: Bool?          // nil or false for users, true for groups
    let isFriend: Bool?         // nil or false for non-friends, true for friends
    let status: String?         // Status text
    let photoCount: Int?        // Total photos count
    let about: String?          // About text
    let site: String?           // Personal site url
    let isOfficial: Bool?       // Verification check mark
    let deactivated: String?    // "deleted" or "banned"
    let banReason: String?      // Reason for ban
    let banExpires: String?     // Ban expiry date/time
    let isClosed: Bool?         // 1 if private profile
    let canAccessClosed: Bool?  // 1 if viewer can access private profile
    let isBlacklisted: Bool?    // 1 if user blacklisted the viewer
    let isBlacklistedByMe: Bool? // 1 if viewer blacklisted the user
    let sex: Int?               // 1 = female, 2 = male, 0 = neutral
    let isAdmin: Bool?          // 1/true if current user is admin/manager of group
    let canPost: Bool?          // 1/true if wall posting is allowed
    let canSuggest: Bool?       // 1/true if wall suggestions are allowed
    let canWriteOnWall: Bool?   // 1/true if current user can write on this user's wall

    var isCurrentUser: Bool {
        if let myUID = AuthService.shared.currentUser?.uid, let userUID = uid, myUID == userUID {
            return true
        }
        let myUsername = AuthService.shared.currentUser?.username ?? User.current.username
        if !username.isEmpty && username.lowercased() == myUsername.lowercased() {
            return true
        }
        return false
    }

    var canCreatePost: Bool {
        guard accessStatus == .active else { return false }

        if isCurrentUser {
            return true
        }

        if isGroup == true {
            return isAdmin == true || canPost == true || canSuggest == true
        }

        if isClosed == true && canAccessClosed == false {
            return false
        }

        if let canWrite = canWriteOnWall {
            return canWrite
        }
        if let canP = canPost {
            return canP
        }

        return true
    }

    var accessStatus: ProfileAccessStatus {
        if deactivated == "deleted" {
            return .deleted
        } else if deactivated == "banned" {
            return .banned(reason: banReason)
        } else if isBlacklisted == true {
            return .blacklistedByThem
        } else if isClosed == true && canAccessClosed == false {
            return .privateProfile
        } else if isBlacklistedByMe == true {
            return .blacklistedByMe
        } else {
            return .active
        }
    }

    init(id: UUID = UUID(),
         uid: Int? = nil,
         username: String,
         displayName: String,
         avatarURL: URL? = nil,
         city: String? = nil,
         isOnline: Bool = false,
         onlinePlatform: String? = nil,
         lastSeen: String? = nil,
         isGroup: Bool = false,
         isFriend: Bool = false,
         status: String? = nil,
         photoCount: Int? = nil,
         about: String? = nil,
         site: String? = nil,
         isOfficial: Bool = false,
         deactivated: String? = nil,
         banReason: String? = nil,
         banExpires: String? = nil,
         isClosed: Bool? = nil,
         canAccessClosed: Bool? = nil,
         isBlacklisted: Bool? = nil,
         isBlacklistedByMe: Bool? = nil,
         sex: Int? = nil,
         isAdmin: Bool? = nil,
         canPost: Bool? = nil,
         canSuggest: Bool? = nil,
         canWriteOnWall: Bool? = nil) {
        self.id = id
        self.uid = uid
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.city = city
        self.isOnline = isOnline
        self.onlinePlatform = onlinePlatform
        self.lastSeen = lastSeen
        self.isGroup = isGroup
        self.isFriend = isFriend
        self.status = status
        self.photoCount = photoCount
        self.about = about
        self.site = site
        self.isOfficial = isOfficial
        self.deactivated = deactivated
        self.banReason = banReason
        self.banExpires = banExpires
        self.isClosed = isClosed
        self.canAccessClosed = canAccessClosed
        self.isBlacklisted = isBlacklisted
        self.isBlacklistedByMe = isBlacklistedByMe
        self.sex = sex
        self.isAdmin = isAdmin
        self.canPost = canPost
        self.canSuggest = canSuggest
        self.canWriteOnWall = canWriteOnWall
    }
}

extension User {
    static let current = User(
        uid: 1,
        username: "user",
        displayName: "User",
        city: "User",
        isOnline: true,
        status: "User",
        photoCount: 12,
        about: "User",
        site: "https://openvk.org",
        isOfficial: true
    )
}
