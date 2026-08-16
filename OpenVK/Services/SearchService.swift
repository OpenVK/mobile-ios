//
//  SearchService.swift
//  OpenVK for iOS
//
//  Глобальный поиск.
//

import Foundation

protocol SearchServiceProtocol {
    func searchUsers(query: String, completion: @escaping ([User]) -> Void)
    func searchPosts(query: String, completion: @escaping ([Post]) -> Void)
}

struct VKSearchResponseInner<T: Decodable>: Decodable {
    let count: Int?
    let items: [T]?
}

final class SearchService: SearchServiceProtocol {

    static let shared = SearchService()

    private init() {}

    func searchUsers(query: String, completion: @escaping ([User]) -> Void) {
        guard !query.isEmpty else { completion([]); return }
        
        let fields = "photo_100,photo_200,city,online,status,friend_status,counters,about,personal,sex,site,last_seen,verified"
        APIClient.shared.call(
            method: "users.search",
            parameters: ["q": query, "fields": fields, "count": "30"],
            httpMethod: "GET",
            as: VKSearchResponseInner<VKUserProfile>.self
        ) { result in
            switch result {
            case .success(let inner):
                let mapped = (inner.items ?? []).map { vkUser -> User in
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
                        isOfficial: vkUser.verified == 1
                    )
                }
                completion(mapped)
            case .failure:
                completion([])
            }
        }
    }

    func searchPosts(query: String, completion: @escaping ([Post]) -> Void) {
        guard !query.isEmpty else { completion([]); return }
        
        APIClient.shared.call(
            method: "wall.search",
            parameters: ["q": query, "extended": "1", "count": "30"],
            httpMethod: "GET",
            as: VKFeedResponse.self
        ) { result in
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
