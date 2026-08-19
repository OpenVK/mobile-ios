//
//  SearchService.swift
//  OpenVK for iOS
//
//  Глобальный поиск по всем категориям.
//

import Foundation
import SwiftUI

struct SearchAllResults {
    var users: [User] = []
    var groups: [Community] = []
    var posts: [Post] = []
    var videos: [Video] = []
    var audios: [AudioTrack] = []
    var documents: [AppDocument] = []
    
    var isEmpty: Bool {
        users.isEmpty && groups.isEmpty && posts.isEmpty && videos.isEmpty && audios.isEmpty && documents.isEmpty
    }
}

protocol SearchServiceProtocol {
    func searchUsers(query: String, sort: Int, onlyOnline: Bool, offset: Int, count: Int, completion: @escaping ([User]) -> Void)
    func searchGroups(query: String, sort: Int, offset: Int, count: Int, completion: @escaping ([Community]) -> Void)
    func searchPosts(query: String, count: Int, startFrom: String?, completion: @escaping ([Post]) -> Void)
    func searchVideos(query: String, sort: Int, offset: Int, count: Int, completion: @escaping ([Video]) -> Void)
    func searchAudios(query: String, sort: Int, performerOnly: Bool, withLyrics: Bool, offset: Int, count: Int, completion: @escaping ([AudioTrack]) -> Void)
    func searchDocuments(query: String, type: Int, offset: Int, count: Int, completion: @escaping ([AppDocument]) -> Void)
    func searchAll(query: String, completion: @escaping (SearchAllResults) -> Void)
}

extension SearchServiceProtocol {
    func searchUsers(query: String, offset: Int = 0, count: Int = 30, completion: @escaping ([User]) -> Void) {
        searchUsers(query: query, sort: 4, onlyOnline: false, offset: offset, count: count, completion: completion)
    }
    func searchGroups(query: String, offset: Int = 0, count: Int = 30, completion: @escaping ([Community]) -> Void) {
        searchGroups(query: query, sort: 0, offset: offset, count: count, completion: completion)
    }
    func searchVideos(query: String, offset: Int = 0, count: Int = 20, completion: @escaping ([Video]) -> Void) {
        searchVideos(query: query, sort: 0, offset: offset, count: count, completion: completion)
    }
    func searchAudios(query: String, offset: Int = 0, count: Int = 30, completion: @escaping ([AudioTrack]) -> Void) {
        searchAudios(query: query, sort: 2, performerOnly: false, withLyrics: false, offset: offset, count: count, completion: completion)
    }
    func searchDocuments(query: String, offset: Int = 0, count: Int = 30, completion: @escaping ([AppDocument]) -> Void) {
        searchDocuments(query: query, type: 0, offset: offset, count: count, completion: completion)
    }
}

struct VKSearchGenericResponse<T: Decodable>: Decodable {
    let count: Int?
    let items: [T]?
}

typealias VKSearchResponseInner<T: Decodable> = VKSearchGenericResponse<T>

struct VKSearchAudioItem: Decodable {
    let id: Int?
    let aid: Int?
    let ownerId: Int?
    let artist: String?
    let title: String?
    let duration: Int?
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case id, aid, artist, title, duration, url
        case ownerId = "owner_id"
        case ownerIdCamel = "ownerId"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(Int.self, forKey: .id)
        aid = try? container.decode(Int.self, forKey: .aid)
        ownerId = (try? container.decode(Int.self, forKey: .ownerId)) ?? (try? container.decode(Int.self, forKey: .ownerIdCamel))
        artist = try? container.decode(String.self, forKey: .artist)
        title = try? container.decode(String.self, forKey: .title)
        duration = try? container.decode(Int.self, forKey: .duration)
        url = try? container.decode(String.self, forKey: .url)
    }
}

struct VKSearchGroupItemDTO: Decodable {
    let id: Int?
    let name: String?
    let screenName: String?
    let photo100: String?
    let membersCount: Int?
    let verified: Int?
    let isAdmin: Bool?
    let canPost: Bool?
    let canSuggest: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, verified
        case screenName = "screen_name"
        case screenNameCamel = "screenName"
        case photo100 = "photo_100"
        case photo100Camel = "photo100"
        case photo200 = "photo_200"
        case photo50 = "photo_50"
        case membersCount = "members_count"
        case membersCountCamel = "membersCount"
        case isAdmin = "is_admin"
        case isAdminCamel = "isAdmin"
        case canPost = "can_post"
        case canPostCamel = "canPost"
        case canSuggest = "can_suggest"
        case canSuggestCamel = "canSuggest"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(Int.self, forKey: .id)
        name = try? container.decode(String.self, forKey: .name)
        screenName = (try? container.decode(String.self, forKey: .screenName)) ?? (try? container.decode(String.self, forKey: .screenNameCamel))
        photo100 = (try? container.decode(String.self, forKey: .photo100)) ?? (try? container.decode(String.self, forKey: .photo100Camel)) ?? (try? container.decode(String.self, forKey: .photo200)) ?? (try? container.decode(String.self, forKey: .photo50))
        membersCount = (try? container.decode(Int.self, forKey: .membersCount)) ?? (try? container.decode(Int.self, forKey: .membersCountCamel))
        if let intVal = try? container.decode(Int.self, forKey: .verified) {
            verified = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .verified) {
            verified = boolVal ? 1 : 0
        } else {
            verified = nil
        }
        
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

final class SearchService: SearchServiceProtocol {

    static let shared = SearchService()

    private init() {}

    func searchUsers(query: String, sort: Int = 4, onlyOnline: Bool = false, offset: Int = 0, count: Int = 30, completion: @escaping ([User]) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let fields = "photo_100,photo_200,city,online,status,friend_status,counters,about,personal,sex,site,last_seen,verified,can_write_private_message"
        var params: [String: String] = [
            "q": trimmed,
            "fields": fields,
            "count": "\(count)",
            "offset": "\(offset)",
            "sort": "\(sort)"
        ]
        if onlyOnline {
            params["online"] = "1"
        }
        
        APIClient.shared.call(
            method: "users.search",
            parameters: params,
            httpMethod: "GET",
            as: VKSearchGenericResponse<VKUserProfile>.self
        ) { [weak self] (result: Result<VKSearchGenericResponse<VKUserProfile>, APIError>) in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let mapped = self.mapUsers(response.items ?? [])
                completion(mapped)
            case .failure:
                completion([])
            }
        }
    }

    func searchGroups(query: String, sort: Int = 0, offset: Int = 0, count: Int = 30, completion: @escaping ([Community]) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let params: [String: String] = [
            "q": trimmed,
            "count": "\(count)",
            "offset": "\(offset)",
            "sort": "\(sort)",
            "fields": "screen_name,is_admin,is_member,is_advertiser,photo_50,photo_100,photo_200,members_count,verified,can_post,can_suggest"
        ]
        
        APIClient.shared.call(
            method: "groups.search",
            parameters: params,
            httpMethod: "GET",
            as: VKSearchGenericResponse<VKSearchGroupItemDTO>.self
        ) { [weak self] (result: Result<VKSearchGenericResponse<VKSearchGroupItemDTO>, APIError>) in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                var mapped = self.mapGroups(response.items ?? [])
                if sort == 1 {
                    mapped.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                }
                completion(mapped)
            case .failure:
                completion([])
            }
        }
    }

    func searchPosts(query: String, count: Int = 30, startFrom: String? = nil, completion: @escaping ([Post]) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            var params: [String: String] = [
                "count": "\(count)",
                "filters": "post"
            ]
            if let startFrom = startFrom, !startFrom.isEmpty {
                params["start_from"] = startFrom
            }
            APIClient.shared.call(
                method: "newsfeed.get",
                parameters: params,
                httpMethod: "GET",
                as: VKFeedResponse.self
            ) { (result: Result<VKFeedResponse, APIError>) in
                switch result {
                case .success(let response):
                    let mapped = FeedService.shared.mapVKFeed(response)
                    completion(mapped)
                case .failure:
                    completion([])
                }
            }
        } else {
            var params: [String: String] = [
                "q": trimmed,
                "extended": "1",
                "count": "\(count)"
            ]
            if let startFrom = startFrom, !startFrom.isEmpty {
                params["start_from"] = startFrom
            }
            
            APIClient.shared.call(
                method: "newsfeed.search",
                parameters: params,
                httpMethod: "GET",
                as: VKFeedResponse.self
            ) { (result: Result<VKFeedResponse, APIError>) in
                switch result {
                case .success(let response):
                    let mapped = FeedService.shared.mapVKFeed(response)
                    completion(mapped)
                case .failure:
                    completion([])
                }
            }
        }
    }

    func searchVideos(query: String, sort: Int = 0, offset: Int = 0, count: Int = 20, completion: @escaping ([Video]) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let params: [String: String] = [
            "q": trimmed,
            "count": "\(count)",
            "offset": "\(offset)",
            "sort": "\(sort)",
            "extended": "1"
        ]
        
        APIClient.shared.call(
            method: "video.search",
            parameters: params,
            httpMethod: "GET",
            as: VKVideosResponse.self
        ) { [weak self] (result: Result<VKVideosResponse, APIError>) in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let mapped = self.mapVideos(response.items ?? [])
                completion(mapped)
            case .failure:
                completion([])
            }
        }
    }

    func searchAudios(query: String, sort: Int = 2, performerOnly: Bool = false, withLyrics: Bool = false, offset: Int = 0, count: Int = 30, completion: @escaping ([AudioTrack]) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            let params: [String: String] = [
                "count": "\(count)",
                "offset": "\(offset)"
            ]
            APIClient.shared.call(
                method: "audio.getPopular",
                parameters: params,
                httpMethod: "GET",
                as: VKSearchGenericResponse<VKSearchAudioItem>.self
            ) { [weak self] (result: Result<VKSearchGenericResponse<VKSearchAudioItem>, APIError>) in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    let mapped = self.mapAudios(response.items ?? [])
                    completion(mapped)
                case .failure:
                    completion([])
                }
            }
        } else {
            var params: [String: String] = [
                "q": trimmed,
                "count": "\(count)",
                "offset": "\(offset)",
                "sort": "\(sort)"
            ]
            if performerOnly {
                params["performer_only"] = "1"
            }
            if withLyrics {
                params["lyrics"] = "1"
            }
            
            APIClient.shared.call(
                method: "audio.search",
                parameters: params,
                httpMethod: "GET",
                as: VKSearchGenericResponse<VKSearchAudioItem>.self
            ) { [weak self] (result: Result<VKSearchGenericResponse<VKSearchAudioItem>, APIError>) in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    let mapped = self.mapAudios(response.items ?? [])
                    completion(mapped)
                case .failure:
                    completion([])
                }
            }
        }
    }

    func searchDocuments(query: String, type: Int = 0, offset: Int = 0, count: Int = 30, completion: @escaping ([AppDocument]) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var params: [String: String] = [
            "q": trimmed,
            "search_own": "0",
            "count": "\(count)",
            "offset": "\(offset)"
        ]
        if type > 0 {
            params["type"] = "\(type)"
        }
        
        APIClient.shared.call(
            method: "docs.search",
            parameters: params,
            httpMethod: "GET",
            as: VKDocumentResponse.self
        ) { (result: Result<VKDocumentResponse, APIError>) in
            switch result {
            case .success(let response):
                let items = (response.items ?? []).map { $0.toAppDocument() }
                completion(items)
            case .failure:
                completion([])
            }
        }
    }

    func searchAll(query: String, completion: @escaping (SearchAllResults) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var results = SearchAllResults()
        let group = DispatchGroup()
        
        group.enter()
        searchUsers(query: trimmed, offset: 0, count: 5) { users in
            results.users = users
            group.leave()
        }
        
        group.enter()
        searchGroups(query: trimmed, offset: 0, count: 5) { groups in
            results.groups = groups
            group.leave()
        }
        
        group.enter()
        searchPosts(query: trimmed, count: 5, startFrom: nil) { posts in
            results.posts = posts
            group.leave()
        }
        
        group.enter()
        searchVideos(query: trimmed, offset: 0, count: 6) { videos in
            results.videos = videos
            group.leave()
        }
        
        group.enter()
        searchAudios(query: trimmed, offset: 0, count: 5) { audios in
            results.audios = audios
            group.leave()
        }
        
        group.enter()
        searchDocuments(query: trimmed, offset: 0, count: 5) { docs in
            results.documents = docs
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }

    private func mapUsers(_ items: [VKUserProfile]) -> [User] {
        return items.map { vkUser -> User in
            let name = "\(vkUser.firstName ?? "") \(vkUser.lastName ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
            let lastSeenText: String?
            if let ls = vkUser.lastSeen?.time {
                let date = Date(timeIntervalSince1970: ls)
                lastSeenText = date.openvkLastSeen(sex: vkUser.sex)
            } else {
                lastSeenText = nil
            }
            return User(
                uid: vkUser.id,
                username: vkUser.screenName ?? "id\(vkUser.id)",
                displayName: name.isEmpty ? "Пользователь" : name,
                avatarURL: (vkUser.photo200 ?? vkUser.photo100).flatMap { URL(string: $0) },
                city: vkUser.city?.title,
                isOnline: vkUser.online == 1,
                onlinePlatform: vkUser.lastSeen?.platformName,
                lastSeen: lastSeenText,
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
                canPost: vkUser.canPost == 1,
                canWriteOnWall: vkUser.canWriteOnWall == 1
            )
        }
    }

    private func mapGroups(_ items: [VKSearchGroupItemDTO]) -> [Community] {
        return items.map { g -> Community in
            Community(
                vkID: g.id,
                name: g.name ?? "Сообщество",
                screenName: g.screenName,
                photo100: g.photo100,
                memberCount: g.membersCount ?? 0,
                isOfficial: g.verified == 1,
                isAdmin: g.isAdmin == true,
                canPost: g.canPost == true,
                canSuggest: g.canSuggest == true
            )
        }
    }

    private func mapVideos(_ items: [VKVideoAttachment]) -> [Video] {
        return items.map { item -> Video in
            let thumbStr = item.image?.last?.url ?? item.image?.first?.url
            let imageURL = thumbStr.flatMap { URL(string: $0) }
            let durationSeconds = item.duration ?? 0
            let durationStr = self.formatDuration(durationSeconds)
            
            return Video(
                vkID: item.id,
                ownerID: item.ownerId,
                title: item.title ?? "Видеозапись",
                duration: durationStr,
                imageURL: imageURL,
                playerURL: item.player.flatMap { URL(string: $0) },
                files: item.files ?? [:],
                likesCount: item.likes?.count ?? 0,
                commentsCount: item.comments?.count ?? 0,
                repostsCount: item.reposts?.count ?? 0,
                isLiked: (item.likes?.userLikes ?? 0) == 1
            )
        }
    }

    private func mapAudios(_ items: [VKSearchAudioItem]) -> [AudioTrack] {
        let colors: [Color] = [.appAccent, .blue, .purple, .orange, .pink, .indigo, .teal]
        return items.enumerated().map { index, item -> AudioTrack in
            let durationSec = item.duration ?? 0
            let durationStr = self.formatDuration(durationSec)
            let color = colors[index % colors.count]
            return AudioTrack(
                vkID: item.id ?? item.aid,
                ownerID: item.ownerId,
                title: item.title ?? "Аудиозапись",
                artist: item.artist ?? "Исполнитель",
                duration: durationStr,
                durationSeconds: durationSec,
                url: item.url,
                color: color,
                systemName: "music.note"
            )
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0:00" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
