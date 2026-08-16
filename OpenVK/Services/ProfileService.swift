//
//  ProfileService.swift
//  OpenVK for iOS
//
//  Информация о профиле пользователя.
//

import Foundation
import SwiftUI

protocol ProfileServiceProtocol {
    func fetchProfile(username: String, completion: @escaping (Result<User, Error>) -> Void)
    func fetchWall(ownerID: Int, offset: Int, completion: @escaping (Result<[Post], Error>) -> Void)
    func fetchPhotos(ownerID: Int, completion: @escaping (Result<[Photo], Error>) -> Void)
    func fetchAlbums(ownerID: Int, completion: @escaping (Result<[PhotoAlbum], Error>) -> Void)
    func fetchAlbumPhotos(ownerID: Int, albumID: Int, completion: @escaping (Result<[Photo], Error>) -> Void)
    func fetchVideos(ownerID: Int, completion: @escaping (Result<[Video], Error>) -> Void)
}

final class ProfileService: ProfileServiceProtocol {

    static let shared = ProfileService()

    private init() {}

    func fetchProfile(username: String, completion: @escaping (Result<User, Error>) -> Void) {
        APIClient.shared.call(
            method: "utils.resolveScreenName",
            parameters: ["screen_name": username],
            httpMethod: "GET",
            as: VKResolveScreenNameResponse.self
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let resolveResponse):
                let objectID = resolveResponse.objectId ?? 0
                if resolveResponse.type == "group" {
                    self.fetchGroupInfo(groupID: objectID, username: username, completion: completion)
                } else {
                    self.fetchUserInfo(userID: objectID, username: username, completion: completion)
                }
                
            case .failure(let error):
                #if DEBUG
                print("utils.resolveScreenName failed for \(username): \(error). Trying fallback parsing.")
                #endif
                
                if username.hasPrefix("club") {
                    let cleanID = username.dropFirst(4)
                    if let integerID = Int(cleanID) {
                        self.fetchGroupInfo(groupID: integerID, username: username, completion: completion)
                        return
                    }
                } else if username.hasPrefix("public") {
                    let cleanID = username.dropFirst(6)
                    if let integerID = Int(cleanID) {
                        self.fetchGroupInfo(groupID: integerID, username: username, completion: completion)
                        return
                    }
                } else if username.hasPrefix("event") {
                    let cleanID = username.dropFirst(5)
                    if let integerID = Int(cleanID) {
                        self.fetchGroupInfo(groupID: integerID, username: username, completion: completion)
                        return
                    }
                }
                
                let cleanID = username.replacingOccurrences(of: "id", with: "")
                if let integerID = Int(cleanID) {
                    self.fetchUserInfo(userID: integerID, username: username, completion: completion)
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    private func fetchUserInfo(userID: Int, username: String, completion: @escaping (Result<User, Error>) -> Void) {
        let fields = "photo_100,photo_200,city,online,status,friend_status,counters,about,personal,sex,site,last_seen,verified,screen_name,deactivated,ban_reason,is_closed,can_access_closed,blacklisted,blacklisted_by_me,can_write_on_wall,can_post"

        APIClient.shared.callWithCache(
            method: "users.get",
            parameters: ["user_ids": "\(userID)", "fields": fields],
            httpMethod: "GET",
            cacheKey: "profile_user_\(userID)",
            as: [VKUserProfile].self
        ) { result in
            switch result {
            case .success(let users):
                if let vkUser = users.first {
                    let rawName = "\(vkUser.firstName ?? "") \(vkUser.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                    let displayName: String
                    if vkUser.deactivated == "deleted" {
                        displayName = rawName.isEmpty ? "DELETED" : rawName
                    } else {
                        displayName = rawName.isEmpty ? "Пользователь" : rawName
                    }

                    let user = User(
                        uid: vkUser.id,
                        username: vkUser.screenName ?? username,
                        displayName: displayName,
                        avatarURL: (vkUser.photo200 ?? vkUser.photo100).flatMap { URL(string: $0) },
                        city: vkUser.city?.title,
                        isOnline: vkUser.online == 1,
                        onlinePlatform: vkUser.lastSeen?.platformName,
                        lastSeen: vkUser.lastSeen?.time != nil ? Date(timeIntervalSince1970: vkUser.lastSeen!.time!).openvkLastSeen(sex: vkUser.sex) : nil,
                        isFriend: vkUser.friendStatus == 3,
                        status: vkUser.status,
                        photoCount: vkUser.counters?.photos,
                        about: vkUser.about,
                        site: vkUser.site,
                        isOfficial: vkUser.verified == 1,
                        deactivated: vkUser.deactivated,
                        banReason: vkUser.banReason,
                        banExpires: vkUser.banExpires,
                        isClosed: vkUser.isClosed == 1,
                        canAccessClosed: vkUser.canAccessClosed == 1,
                        isBlacklisted: vkUser.blacklisted == 1,
                        isBlacklistedByMe: vkUser.blacklistedByMe == 1,
                        sex: vkUser.sex,
                        isAdmin: false,
                        canPost: vkUser.canPost.map { $0 == 1 },
                        canSuggest: false,
                        canWriteOnWall: vkUser.canWriteOnWall.map { $0 == 1 }
                    )
                    completion(.success(user))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func fetchGroupInfo(groupID: Int, username: String, completion: @escaping (Result<User, Error>) -> Void) {
        APIClient.shared.call(
            method: "groups.getById",
            parameters: ["group_ids": "\(groupID)", "fields": "status,description,site,verified,can_post,is_admin,can_suggest,photo_50,photo_100,photo_200"],
            httpMethod: "GET",
            as: [VKGroupProfile].self
        ) { result in
            switch result {
            case .success(let groups):
                if let vkGroup = groups.first {
                    let user = User(
                        uid: -vkGroup.id, // ID сообществ в VK передаются со знаком минус
                        username: vkGroup.screenName ?? username,
                        displayName: vkGroup.name ?? "Сообщество",
                        avatarURL: (vkGroup.photo200 ?? vkGroup.photo100).flatMap { URL(string: $0) },
                        isGroup: true,
                        isFriend: vkGroup.isMember == 1,
                        status: vkGroup.status,
                        about: vkGroup.description,
                        site: vkGroup.site,
                        isOfficial: vkGroup.verified == 1,
                        isAdmin: vkGroup.isAdmin == true,
                        canPost: vkGroup.canPost == true,
                        canSuggest: vkGroup.canSuggest == true
                    )
                    completion(.success(user))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchWall(ownerID: Int, offset: Int, completion: @escaping (Result<[Post], Error>) -> Void) {
        let params: [String: String] = [
            "owner_id": "\(ownerID)",
            "extended": "1",
            "offset": "\(offset)",
            "count": "20"
        ]
        if offset == 0 {
            APIClient.shared.callWithCache(
                method: "wall.get",
                parameters: params,
                httpMethod: "GET",
                cacheKey: "wall_\(ownerID)_first",
                as: VKFeedResponse.self
            ) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response): completion(.success(self.mapVKWall(response)))
                case .failure(let error): completion(.failure(error))
                }
            }
        } else {
            APIClient.shared.call(
                method: "wall.get",
                parameters: params,
                httpMethod: "GET",
                as: VKFeedResponse.self
            ) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response): completion(.success(self.mapVKWall(response)))
                case .failure(let error): completion(.failure(error))
                }
            }
        }
    }

    func fetchPhotos(ownerID: Int, completion: @escaping (Result<[Photo], Error>) -> Void) {
        APIClient.shared.call(
            method: "photos.getAll",
            parameters: [
                "owner_id": "\(ownerID)",
                "count": "24",
                "photo_sizes": "1"
            ],
            httpMethod: "GET",
            as: VKPhotosResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let items = response.items ?? []
                let mapped = items.map { item -> Photo in
                    let urlStr = item.sizes?.array.first(where: { $0.type == "z" || $0.type == "y" || $0.type == "x" })?.url 
                        ?? item.sizes?.array.last?.url 
                        ?? item.sizes?.array.first?.url 
                        ?? item.sizes?.array.first?.src
                    let url = self.forceHTTPS(urlStr)
                    return Photo(
                        imageURL: url,
                        systemName: "photo",
                        color: .clear
                    )
                }
                completion(.success(mapped))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchAlbums(ownerID: Int, completion: @escaping (Result<[PhotoAlbum], Error>) -> Void) {
        let resolvedOwnerID = ownerID == 0 ? (AuthService.shared.currentUser?.uid ?? 0) : ownerID
        APIClient.shared.call(
            method: "photos.getAlbums",
            parameters: [
                "owner_id": "\(resolvedOwnerID)",
                "need_covers": "1",
                "photo_sizes": "1"
            ],
            httpMethod: "GET",
            as: VKPhotoAlbumsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let items = response.items ?? []
                let mapped = items.map { item -> PhotoAlbum in
                    let coverURL = self.forceHTTPS(item.thumbSrc)
                    return PhotoAlbum(
                        vkID: item.id ?? 0,
                        ownerID: item.ownerId ?? ownerID,
                        title: item.title ?? "Альбом",
                        photos: [],
                        coverURL: coverURL,
                        size: item.size ?? 0
                    )
                }
                completion(.success(mapped))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchAlbumPhotos(ownerID: Int, albumID: Int, completion: @escaping (Result<[Photo], Error>) -> Void) {
        let resolvedOwnerID = ownerID == 0 ? (AuthService.shared.currentUser?.uid ?? 0) : ownerID
        APIClient.shared.call(
            method: "photos.get",
            parameters: [
                "owner_id": "\(resolvedOwnerID)",
                "album_id": "\(albumID)",
                "photo_sizes": "1",
                "extended": "1",
                "count": "100"
            ],
            httpMethod: "GET",
            as: VKPhotosResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let items = response.items ?? []
                let mapped = items.map { item -> Photo in
                    let urlStr = item.sizes?.array.first(where: { $0.type == "z" || $0.type == "y" || $0.type == "x" })?.url 
                        ?? item.sizes?.array.last?.url 
                        ?? item.sizes?.array.first?.url 
                        ?? item.sizes?.array.first?.src
                    let url = self.forceHTTPS(urlStr)
                    return Photo(
                        vkID: item.id,
                        ownerID: item.ownerId,
                        imageURL: url,
                        systemName: "photo",
                        color: .clear,
                        likesCount: item.likes?.count ?? 0,
                        commentsCount: item.comments?.count ?? 0,
                        repostsCount: item.reposts?.count ?? 0,
                        isLiked: (item.likes?.userLikes ?? 0) == 1
                    )
                }
                completion(.success(mapped))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchVideos(ownerID: Int, completion: @escaping (Result<[Video], Error>) -> Void) {
        let resolvedOwnerID = ownerID == 0 ? (AuthService.shared.currentUser?.uid ?? 0) : ownerID
        APIClient.shared.call(
            method: "video.get",
            parameters: [
                "owner_id": "\(resolvedOwnerID)",
                "extended": "1",
                "count": "50"
            ],
            httpMethod: "GET",
            as: VKVideosResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let items = response.items ?? []
                let mapped = items.map { item -> Video in
                    let thumbStr = item.image?.last?.url ?? item.image?.first?.url
                    let imageURL = thumbStr.flatMap { URL(string: $0) }
                    
                    let durationSeconds = item.duration ?? 0
                    let durationStr: String
                    if durationSeconds > 0 {
                        let hours = durationSeconds / 3600
                        let minutes = (durationSeconds % 3600) / 60
                        let seconds = durationSeconds % 60
                        if hours > 0 {
                            durationStr = String(format: "%d:%02d:%02d", hours, minutes, seconds)
                        } else {
                            durationStr = String(format: "%d:%02d", minutes, seconds)
                        }
                    } else {
                        durationStr = "0:00"
                    }
                    
                    var filesDict: [String: String] = [:]
                    if let files = item.files {
                        filesDict = files
                    }
                    
                    return Video(
                        vkID: item.id,
                        ownerID: item.ownerId,
                        title: item.title ?? "Видеозапись",
                        duration: durationStr,
                        imageURL: imageURL,
                        playerURL: item.player.flatMap { URL(string: $0) },
                        files: filesDict,
                        likesCount: item.likes?.count ?? 0,
                        commentsCount: item.comments?.count ?? 0,
                        repostsCount: item.reposts?.count ?? 0,
                        isLiked: (item.likes?.userLikes ?? 0) == 1
                    )
                }
                completion(.success(mapped))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func forceHTTPS(_ urlString: String?) -> URL? {
        guard var str = urlString else { return nil }
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            let host = AppConfig.currentHost
            var base = host
            if !base.lowercased().hasPrefix("http://") && !base.lowercased().hasPrefix("https://") {
                base = "https://" + base
            }
            if !base.hasSuffix("/") && !str.hasPrefix("/") {
                base += "/"
            }
            str = base + str
        }
        return URL(string: str)
    }

    private func mapVKWall(_ response: VKFeedResponse) -> [Post] {
        let profiles = response.profiles ?? []
        let groups = response.groups ?? []
        let items = response.items ?? []
        
        return items.map { item -> Post in
            return mapVKPost(item, profiles: profiles, groups: groups)
        }
    }

    private func mapVKPost(_ item: VKPost, profiles: [VKProfile], groups: [VKGroup]) -> Post {
        let itemSourceId = item.sourceId ?? item.fromId ?? 0
        let itemOwnerId = item.ownerId ?? item.sourceId ?? item.fromId ?? 0
        
        let author: User
        if itemSourceId > 0 {
            if let p = profiles.first(where: { ($0.id ?? 0) == itemSourceId }) {
                author = User(
                    uid: itemSourceId,
                    username: p.screenName ?? "id\(itemSourceId)",
                    displayName: "\(p.firstName ?? "") \(p.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                    avatarURL: p.photo100.flatMap { URL(string: $0) },
                    isOfficial: p.verified == 1
                )
            } else {
                author = User(uid: itemSourceId, username: "id\(itemSourceId)", displayName: "Пользователь \(itemSourceId)")
            }
        } else {
            let absId = abs(itemSourceId)
            if let g = groups.first(where: { ($0.id ?? 0) == absId }) {
                author = User(
                    uid: -absId,
                    username: g.screenName ?? "club\(absId)",
                    displayName: g.name ?? "Сообщество \(absId)",
                    avatarURL: g.photo100.flatMap { URL(string: $0) },
                    isGroup: true,
                    isOfficial: g.verified == 1
                )
            } else {
                author = User(uid: -absId, username: "club\(absId)", displayName: "Сообщество \(absId)", isGroup: true)
            }
        }
        
        let date = Date(timeIntervalSince1970: item.date ?? Date().timeIntervalSince1970)
        let timeAgo = date.timeAgoDescription()
        
        var localAttachments: [Attachment] = []
        if let atts = item.attachments {
            for att in atts {
                if att.type == "photo", let p = att.photo {
                    if let sizes = p.sizes, !sizes.isEmpty {
                        let urlStr = sizes.first(where: { $0.type == "z" || $0.type == "y" || $0.type == "x" })?.url 
                            ?? sizes.last?.url 
                            ?? sizes.first?.url 
                            ?? sizes.first?.src
                        if let url = urlStr {
                            localAttachments.append(.remoteImage(
                                url: url,
                                id: p.id,
                                ownerID: p.ownerId,
                                likesCount: p.likes?.count ?? 0,
                                commentsCount: p.comments?.count ?? 0,
                                repostsCount: p.reposts?.count ?? 0,
                                isLiked: (p.likes?.userLikes ?? 0) == 1
                            ))
                        } else {
                            localAttachments.append(.image(systemName: "photo"))
                        }
                    }
                } else if att.type == "video", let v = att.video {
                    let coverUrl = v.image?.last?.url ?? v.image?.first?.url ?? ""
                    let directURL = v.files?["mp4_720"] ?? v.files?["mp4_480"] ?? v.files?["mp4_360"] ?? v.files?["mp4_240"] ?? v.player
                    localAttachments.append(.remoteVideo(
                        title: v.title ?? "Видео",
                        duration: formatDuration(v.duration ?? 0),
                        imageURL: coverUrl,
                        videoURL: directURL,
                        id: v.id,
                        ownerID: v.ownerId,
                        files: v.files,
                        likesCount: v.likes?.count ?? 0,
                        commentsCount: v.comments?.count ?? 0,
                        repostsCount: v.reposts?.count ?? 0,
                        isLiked: (v.likes?.userLikes ?? 0) == 1
                    ))
                } else if att.type == "poll", let p = att.poll {
                    let options = p.answers?.map { PollOption(text: $0.text ?? "", votes: $0.votes ?? 0) } ?? []
                    localAttachments.append(.poll(question: p.question ?? "", options: options, totalVotes: p.votes ?? 0))
                } else if att.type == "doc", let d = att.doc {
                    if d.ext?.lowercased() == "gif" {
                        localAttachments.append(.gif(title: d.title ?? "GIF", url: d.url ?? ""))
                    } else {
                        localAttachments.append(.document(title: d.title ?? "Документ", ext: d.ext ?? "", size: formatSize(d.size ?? 0), url: d.url ?? ""))
                    }
                } else if att.type == "audio", let a = att.audio {
                    localAttachments.append(.audio(artist: a.artist ?? "", title: a.title ?? "", duration: formatDuration(a.duration ?? 0)))
                }
            }
        }
        
        var repostsList: [Post] = []
        if let history = item.copyHistory {
            repostsList = history.map { mapVKPost($0, profiles: profiles, groups: groups) }
        }
        
        return Post(
            id: UUID(),
            vkID: item.id,
            ownerID: itemOwnerId,
            author: author,
            platform: item.postSource?.platform,
            timeAgo: timeAgo,
            text: item.text ?? "",
            attachments: localAttachments,
            likes: item.likes?.count ?? 0,
            comments: item.comments?.count ?? 0,
            reposts: item.reposts?.count ?? 0,
            isLiked: (item.likes?.userLikes ?? 0) == 1,
            copyHistory: repostsList,
            isExplicit: item.isExplicit ?? false
        )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }
}

struct VKResolveScreenNameResponse: Decodable {
    let objectId: Int?
    let type: String?
}

struct VKGroupProfile: Decodable {
    let id: Int
    let name: String?
    let screenName: String?
    let photo100: String?
    let photo200: String?
    let status: String?
    let description: String?
    let site: String?
    let verified: Int?
    let isMember: Int?
    let isAdmin: Bool?
    let canPost: Bool?
    let canSuggest: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case screenName = "screen_name"
        case screenNameCamel = "screenName"
        case photo100 = "photo_100"
        case photo100Camel = "photo100"
        case photo200 = "photo_200"
        case photo200Camel = "photo200"
        case status
        case description
        case site
        case verified
        case isMember = "is_member"
        case isMemberCamel = "isMember"
        case isAdmin = "is_admin"
        case isAdminCamel = "isAdmin"
        case canPost = "can_post"
        case canPostCamel = "canPost"
        case canSuggest = "can_suggest"
        case canSuggestCamel = "canSuggest"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try? container.decode(String.self, forKey: .name)
        screenName = (try? container.decode(String.self, forKey: .screenName)) ?? (try? container.decode(String.self, forKey: .screenNameCamel))
        photo100 = (try? container.decode(String.self, forKey: .photo100)) ?? (try? container.decode(String.self, forKey: .photo100Camel))
        photo200 = (try? container.decode(String.self, forKey: .photo200)) ?? (try? container.decode(String.self, forKey: .photo200Camel))
        status = try? container.decode(String.self, forKey: .status)
        description = try? container.decode(String.self, forKey: .description)
        site = try? container.decode(String.self, forKey: .site)
        if let intVal = try? container.decode(Int.self, forKey: .verified) {
            verified = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .verified) {
            verified = boolVal ? 1 : 0
        } else {
            verified = nil
        }
        isMember = (try? container.decode(Int.self, forKey: .isMember)) ?? (try? container.decode(Int.self, forKey: .isMemberCamel))
        
        if let boolVal = (try? container.decode(Bool.self, forKey: .isAdmin)) ?? (try? container.decode(Bool.self, forKey: .isAdminCamel)) {
            isAdmin = boolVal
        } else if let intVal = (try? container.decode(Int.self, forKey: .isAdmin)) ?? (try? container.decode(Int.self, forKey: .isAdminCamel)) {
            isAdmin = intVal == 1
        } else {
            isAdmin = nil
        }
        
        if let boolVal = (try? container.decode(Bool.self, forKey: .canPost)) ?? (try? container.decode(Bool.self, forKey: .canPostCamel)) {
            canPost = boolVal
        } else if let intVal = (try? container.decode(Int.self, forKey: .canPost)) ?? (try? container.decode(Int.self, forKey: .canPostCamel)) {
            canPost = intVal == 1
        } else {
            canPost = nil
        }
        
        if let boolVal = (try? container.decode(Bool.self, forKey: .canSuggest)) ?? (try? container.decode(Bool.self, forKey: .canSuggestCamel)) {
            canSuggest = boolVal
        } else if let intVal = (try? container.decode(Int.self, forKey: .canSuggest)) ?? (try? container.decode(Int.self, forKey: .canSuggestCamel)) {
            canSuggest = intVal == 1
        } else {
            canSuggest = nil
        }
    }
}

struct VKUserProfile: Decodable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let screenName: String?
    let photo100: String?
    let photo200: String?
    let city: VKUserCity?
    let online: Int?
    let lastSeen: VKUserLastSeen?
    let status: String?
    let friendStatus: Int?
    let counters: VKUserCounters?
    let about: String?
    let personal: VKUserPersonal?
    let site: String?
    let verified: Int?
    let bdate: String?
    let bdateVisibility: Int?
    let deactivated: String?
    let banReason: String?
    let banExpires: String?
    let isClosed: Int?
    let canAccessClosed: Int?
    let blacklisted: Int?
    let blacklistedByMe: Int?
    let sex: Int?
    let canWriteOnWall: Int?
    let canPost: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case bdate
        case bdateVisibility = "bdate_visibility"
        case bdateVisibilityCamel = "bdateVisibility"
        case firstName = "first_name"
        case firstNameCamel = "firstName"
        case lastName = "last_name"
        case lastNameCamel = "lastName"
        case screenName = "screen_name"
        case screenNameCamel = "screenName"
        case photo100 = "photo_100"
        case photo100Camel = "photo100"
        case photo200 = "photo_200"
        case photo200Camel = "photo200"
        case city
        case online
        case lastSeen = "last_seen"
        case lastSeenCamel = "lastSeen"
        case status
        case friendStatus = "friend_status"
        case friendStatusCamel = "friendStatus"
        case counters
        case about
        case personal
        case site
        case verified
        case deactivated
        case banReason = "ban_reason"
        case banReasonCamel = "banReason"
        case banExpires = "ban_expires"
        case banExpiresCamel = "banExpires"
        case isClosed = "is_closed"
        case isClosedCamel = "isClosed"
        case canAccessClosed = "can_access_closed"
        case canAccessClosedCamel = "canAccessClosed"
        case blacklisted
        case blacklistedByMe = "blacklisted_by_me"
        case blacklistedByMeCamel = "blacklistedByMe"
        case sex
        case canWriteOnWall = "can_write_on_wall"
        case canWriteOnWallCamel = "canWriteOnWall"
        case canPost = "can_post"
        case canPostCamel = "canPost"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        firstName = (try? container.decode(String.self, forKey: .firstName)) ?? (try? container.decode(String.self, forKey: .firstNameCamel))
        lastName = (try? container.decode(String.self, forKey: .lastName)) ?? (try? container.decode(String.self, forKey: .lastNameCamel))
        screenName = (try? container.decode(String.self, forKey: .screenName)) ?? (try? container.decode(String.self, forKey: .screenNameCamel))
        photo100 = (try? container.decode(String.self, forKey: .photo100)) ?? (try? container.decode(String.self, forKey: .photo100Camel))
        photo200 = (try? container.decode(String.self, forKey: .photo200)) ?? (try? container.decode(String.self, forKey: .photo200Camel))
        city = try? container.decode(VKUserCity.self, forKey: .city)
        online = try? container.decode(Int.self, forKey: .online)
        lastSeen = (try? container.decode(VKUserLastSeen.self, forKey: .lastSeen)) ?? (try? container.decode(VKUserLastSeen.self, forKey: .lastSeenCamel))
        status = try? container.decode(String.self, forKey: .status)
        friendStatus = (try? container.decode(Int.self, forKey: .friendStatus)) ?? (try? container.decode(Int.self, forKey: .friendStatusCamel))
        counters = try? container.decode(VKUserCounters.self, forKey: .counters)
        about = try? container.decode(String.self, forKey: .about)
        personal = try? container.decode(VKUserPersonal.self, forKey: .personal)
        site = try? container.decode(String.self, forKey: .site)
        bdate = try? container.decode(String.self, forKey: .bdate)
        bdateVisibility = (try? container.decode(Int.self, forKey: .bdateVisibility)) ?? (try? container.decode(Int.self, forKey: .bdateVisibilityCamel))
        if let intVal = try? container.decode(Int.self, forKey: .verified) {
            verified = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .verified) {
            verified = boolVal ? 1 : 0
        } else {
            verified = nil
        }
        deactivated = try? container.decode(String.self, forKey: .deactivated)
        banReason = (try? container.decode(String.self, forKey: .banReason)) ?? (try? container.decode(String.self, forKey: .banReasonCamel))
        banExpires = (try? container.decode(String.self, forKey: .banExpires)) ?? (try? container.decode(String.self, forKey: .banExpiresCamel))
        isClosed = (try? container.decode(Int.self, forKey: .isClosed)) ?? (try? container.decode(Int.self, forKey: .isClosedCamel))
        canAccessClosed = (try? container.decode(Int.self, forKey: .canAccessClosed)) ?? (try? container.decode(Int.self, forKey: .canAccessClosedCamel))
        blacklisted = try? container.decode(Int.self, forKey: .blacklisted)
        blacklistedByMe = (try? container.decode(Int.self, forKey: .blacklistedByMe)) ?? (try? container.decode(Int.self, forKey: .blacklistedByMeCamel))
        sex = try? container.decode(Int.self, forKey: .sex)

        if let intVal = try? container.decode(Int.self, forKey: .canWriteOnWall) {
            canWriteOnWall = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .canWriteOnWall) {
            canWriteOnWall = boolVal ? 1 : 0
        } else {
            canWriteOnWall = (try? container.decode(Int.self, forKey: .canWriteOnWallCamel)) ?? ((try? container.decode(Bool.self, forKey: .canWriteOnWallCamel)).map { $0 ? 1 : 0 })
        }

        if let intVal = try? container.decode(Int.self, forKey: .canPost) {
            canPost = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .canPost) {
            canPost = boolVal ? 1 : 0
        } else {
            canPost = (try? container.decode(Int.self, forKey: .canPostCamel)) ?? ((try? container.decode(Bool.self, forKey: .canPostCamel)).map { $0 ? 1 : 0 })
        }
    }
}

struct VKUserCity: Decodable {
    let id: Int?
    let title: String?

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            id = try? container.decode(Int.self, forKey: .id)
            title = try? container.decode(String.self, forKey: .title)
        } else if let stringValue = try? decoder.singleValueContainer().decode(String.self) {
            id = nil
            title = stringValue
        } else {
            id = nil
            title = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title
    }
}

struct VKUserLastSeen: Decodable {
    let time: Double?
    let platform: Int?

    // Коды платформ
    var platformName: String? {
        switch platform {
        case 2: return "iphone"
        case 4: return "android"
        default: return nil
        }
    }
}

struct VKUserCounters: Decodable {
    let friends: Int?
    let photos: Int?
    let audios: Int?
    let videos: Int?
    let notes: Int?
    let groups: Int?
}

struct VKUserPersonal: Decodable {
    let religion: String?
    let langs: [String]?
    let lifeMain: Int?
    let peopleMain: Int?
    let smoking: Int?
    let alcohol: Int?
}

struct VKPhotosResponse: Decodable {
    let count: Int?
    let items: [VKPhotoItem]?
}

struct VKPhotoItem: Decodable {
    let id: Int?
    let ownerId: Int?
    let sizes: VKPhotoSizes?
    let likes: VKLikesInfo?
    let comments: VKCommentsInfo?
    let reposts: VKRepostsInfo?
}

struct VKPhotoAlbumsResponse: Decodable {
    let count: Int?
    let items: [VKPhotoAlbumItem]?
}

struct VKPhotoAlbumItem: Decodable {
    let id: Int?
    let ownerId: Int?
    let title: String?
    let description: String?
    let size: Int?
    let thumbSrc: String?
    let sizes: VKPhotoSizes?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, size, sizes, ownerId, thumbSrc
    }
}

struct VKPhotoSizes: Decodable {
    let array: [VKPhotoSize]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([VKPhotoSize].self) {
            self.array = arr
        } else if let dict = try? container.decode([String: VKPhotoSize].self) {
            self.array = Array(dict.values)
        } else {
            self.array = []
        }
    }
}

struct VKVideosResponse: Decodable {
    let count: Int?
    let items: [VKVideoAttachment]?
}
