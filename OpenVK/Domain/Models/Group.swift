//
//  Group.swift
//  OpenVK for iOS
//
//  Модель группы.
//

import Foundation

struct Community: Identifiable, Hashable {
    let id: UUID
    let vkID: Int?
    let name: String
    let screenName: String?
    let photo100: String?
    let memberCount: Int
    let isOfficial: Bool
    let isAdmin: Bool
    let canPost: Bool
    let canSuggest: Bool

    init(id: UUID = UUID(),
         vkID: Int? = nil,
         name: String,
         screenName: String? = nil,
         photo100: String? = nil,
         memberCount: Int = 0,
         isOfficial: Bool = false,
         isAdmin: Bool = false,
         canPost: Bool = false,
         canSuggest: Bool = false) {
        self.id = id
        self.vkID = vkID
        self.name = name
        self.screenName = screenName
        self.photo100 = photo100
        self.memberCount = memberCount
        self.isOfficial = isOfficial
        self.isAdmin = isAdmin
        self.canPost = canPost
        self.canSuggest = canSuggest
    }
}

extension Community {
    func toUser() -> User {
        User(
            uid: vkID.flatMap { -$0 },
            username: screenName ?? "club\(vkID ?? 0)",
            displayName: name,
            avatarURL: photo100.flatMap { URL(string: $0) },
            isGroup: true,
            isOfficial: isOfficial,
            isAdmin: isAdmin,
            canPost: canPost,
            canSuggest: canSuggest
        )
    }
}
