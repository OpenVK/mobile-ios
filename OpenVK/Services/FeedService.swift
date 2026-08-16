//
//  FeedService.swift
//  OpenVK for iOS
//
//  Работа с лентой записей.
//

import Foundation

protocol FeedServiceProtocol {
    func fetchFeed(isGlobal: Bool,
                   startFrom: String?,
                   completion: @escaping (Result<(posts: [Post], nextFrom: String?), Error>) -> Void)
    func getPostById(ownerID: Int, postID: Int, completion: @escaping (Result<Post, Error>) -> Void)
    func like(post: Post, completion: @escaping (Result<Post, Error>) -> Void)
    func createPost(text: String, ownerID: Int?, attachments: String?, explicit: Bool, fromGroup: Bool, signed: Bool, targetUser: User?, completion: @escaping (Result<Post, Error>) -> Void)
    func uploadPhoto(photoData: Data, ownerID: Int?, completion: @escaping (Result<String, Error>) -> Void)
    func getWallUploadServer(ownerID: Int?, completion: @escaping (Result<String, Error>) -> Void)
    func uploadPhotoToServer(urlString: String, photoData: Data, ownerID: Int?, completion: @escaping (Result<String, Error>) -> Void)
}

final class FeedService: FeedServiceProtocol {

    static let shared = FeedService()

    private init() {}

    func getPostById(ownerID: Int, postID: Int, completion: @escaping (Result<Post, Error>) -> Void) {
        let params: [String: String] = [
            "posts": "\(ownerID)_\(postID)",
            "extended": "1"
        ]
        
        APIClient.shared.call(
            method: "wall.getById",
            parameters: params,
            httpMethod: "GET",
            as: VKFeedResponse.self
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                if let post = self.mapVKFeed(response).first {
                    completion(.success(post))
                } else {
                    let error = NSError(domain: "OpenVK", code: 404, userInfo: [NSLocalizedDescriptionKey: "Запись не найдена"])
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchFeed(isGlobal: Bool,
                   startFrom: String?,
                   completion: @escaping (Result<(posts: [Post], nextFrom: String?), Error>) -> Void) {

        let methodName = isGlobal ? "newsfeed.getGlobal" : "newsfeed.get"
        var params: [String: String] = ["count": "15", "extended": "1", "with_alien_wall_posts": "1"]
        if let startFrom = startFrom {
            params["start_from"] = startFrom
        }

        // Кэшируем только первую страницу (без startFrom)
        if startFrom == nil {
            let cacheKey = "feed_\(methodName)_first"
            APIClient.shared.callWithCache(
                method: methodName,
                parameters: params,
                httpMethod: "GET",
                cacheKey: cacheKey,
                as: VKFeedResponse.self
            ) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    completion(.success((posts: self.mapVKFeed(response), nextFrom: response.nextFrom)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            APIClient.shared.call(
                method: methodName,
                parameters: params,
                httpMethod: "GET",
                as: VKFeedResponse.self
            ) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    completion(.success((posts: self.mapVKFeed(response), nextFrom: response.nextFrom)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func like(post: Post, completion: @escaping (Result<Post, Error>) -> Void) {
        guard let itemID = post.vkID, let ownerID = post.ownerID ?? post.author.uid else {
            var updated = post
            updated.isLiked.toggle()
            updated.likes += updated.isLiked ? 1 : -1
            completion(.success(updated))
            return
        }
        
        let method = post.isLiked ? "likes.delete" : "likes.add"
        let params: [String: String] = [
            "type": "post",
            "owner_id": "\(ownerID)",
            "item_id": "\(itemID)"
        ]
        
        APIClient.shared.call(
            method: method,
            parameters: params,
            httpMethod: "POST",
            as: VKLikesCountResponse.self
        ) { result in
            switch result {
            case .success(let response):
                var updated = post
                updated.isLiked.toggle()
                updated.likes = response.likes ?? (updated.isLiked ? (updated.likes + 1) : max(0, updated.likes - 1))
                completion(.success(updated))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func createPost(
        text: String,
        ownerID: Int? = nil,
        attachments: String? = nil,
        explicit: Bool = false,
        fromGroup: Bool = false,
        signed: Bool = false,
        targetUser: User? = nil,
        completion: @escaping (Result<Post, Error>) -> Void
    ) {
        struct VKWallPostResponse: Decodable {
            let postId: Int?
            enum CodingKeys: String, CodingKey {
                case postId
            }
        }
        
        let ownerId = ownerID ?? AuthService.shared.currentUser?.uid ?? 0
        var params: [String: String] = ["owner_id": String(ownerId), "message": text]
        if let attachments = attachments {
            params["attachments"] = attachments
        }
        if explicit {
            params["explicit"] = "1"
        }
        if ownerId < 0 {
            if fromGroup {
                params["from_group"] = "1"
                if signed {
                    params["signed"] = "1"
                }
            }
        }
        
        APIClient.shared.call(
            method: "wall.post",
            parameters: params,
            httpMethod: "POST",
            as: VKWallPostResponse.self
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                if let postId = response.postId {
                    self.getPostById(ownerID: ownerId, postID: postId) { getResult in
                        switch getResult {
                        case .success(let fetchedPost):
                            completion(.success(fetchedPost))
                        case .failure:
                            let post = self.buildLocalPost(
                                postId: postId,
                                ownerId: ownerId,
                                text: text,
                                attachments: attachments,
                                explicit: explicit,
                                fromGroup: fromGroup,
                                targetUser: targetUser
                            )
                            completion(.success(post))
                        }
                    }
                } else {
                    let post = self.buildLocalPost(
                        postId: nil,
                        ownerId: ownerId,
                        text: text,
                        attachments: attachments,
                        explicit: explicit,
                        fromGroup: fromGroup,
                        targetUser: targetUser
                    )
                    completion(.success(post))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func buildLocalPost(
        postId: Int?,
        ownerId: Int,
        text: String,
        attachments: String?,
        explicit: Bool,
        fromGroup: Bool,
        targetUser: User?
    ) -> Post {
        var localAttachments: [Attachment] = []
        if let attachments = attachments, attachments.starts(with: "photo") {
            localAttachments.append(.image(systemName: "photo"))
        }
        
        let postAuthor: User
        if ownerId < 0 && fromGroup {
            if let target = targetUser {
                postAuthor = target
            } else {
                postAuthor = User(
                    uid: ownerId,
                    username: "club\(abs(ownerId))",
                    displayName: "Сообщество",
                    avatarURL: nil,
                    isGroup: true
                )
            }
        } else {
            postAuthor = AuthService.shared.currentUser ?? .current
        }
        
        return Post(
            vkID: postId,
            ownerID: ownerId,
            author: postAuthor,
            timeAgo: "только что",
            text: text,
            attachments: localAttachments,
            likes: 0,
            comments: 0,
            reposts: 0,
            isLiked: false,
            isExplicit: explicit
        )
    }

    func uploadPhoto(photoData: Data, ownerID: Int?, completion: @escaping (Result<String, Error>) -> Void) {
        var params: [String: String] = [:]
        if let owner = ownerID, owner < 0 {
            params["group_id"] = "\(abs(owner))"
        }
        
        APIClient.shared.call(
            method: "photos.getWallUploadServer",
            parameters: params,
            httpMethod: "GET",
            as: VKUploadServerResponse.self
        ) { result in
            switch result {
            case .success(let response):
                guard let uploadUrl = response.uploadUrl else {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                
                APIClient.shared.upload(
                    urlString: uploadUrl,
                    fileData: photoData,
                    fileName: "photo.jpg",
                    mimeType: "image/jpeg"
                ) { uploadResult in
                    switch uploadResult {
                    case .success(let data):
                        do {
                            let uploadResultDecoded = try JSONDecoder().decode(VKUploadResult.self, from: data)
                            var saveParams = [
                                "photo": uploadResultDecoded.photo,
                                "hash": uploadResultDecoded.hash
                            ]
                            if let owner = ownerID, owner < 0 {
                                saveParams["group_id"] = "\(abs(owner))"
                            }
                            
                            APIClient.shared.call(
                                method: "photos.saveWallPhoto",
                                parameters: saveParams,
                                httpMethod: "POST",
                                as: [VKSavePhotoItem].self
                            ) { saveResult in
                                switch saveResult {
                                case .success(let photosList):
                                    if let firstPhoto = photosList.first {
                                        let att = "photo\(firstPhoto.ownerId)_\(firstPhoto.id)"
                                        completion(.success(att))
                                    } else {
                                        completion(.failure(APIError.invalidResponse))
                                    }
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                        } catch {
                            completion(.failure(APIError.decoding(error)))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getWallUploadServer(ownerID: Int?, completion: @escaping (Result<String, Error>) -> Void) {
        var params: [String: String] = [:]
        if let owner = ownerID, owner < 0 {
            params["group_id"] = "\(abs(owner))"
        }
        
        APIClient.shared.call(
            method: "photos.getWallUploadServer",
            parameters: params,
            httpMethod: "GET",
            as: VKUploadServerResponse.self
        ) { result in
            switch result {
            case .success(let response):
                if let uploadUrl = response.uploadUrl {
                    completion(.success(uploadUrl))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func uploadPhotoToServer(urlString: String, photoData: Data, ownerID: Int?, completion: @escaping (Result<String, Error>) -> Void) {
        APIClient.shared.upload(
            urlString: urlString,
            fileData: photoData,
            fileName: "photo.jpg",
            mimeType: "image/jpeg"
        ) { uploadResult in
            switch uploadResult {
            case .success(let data):
                do {
                    let uploadResultDecoded = try JSONDecoder().decode(VKUploadResult.self, from: data)
                    var saveParams = [
                        "photo": uploadResultDecoded.photo,
                        "hash": uploadResultDecoded.hash
                    ]
                    if let owner = ownerID, owner < 0 {
                        saveParams["group_id"] = "\(abs(owner))"
                    }
                    
                    APIClient.shared.call(
                        method: "photos.saveWallPhoto",
                        parameters: saveParams,
                        httpMethod: "POST",
                        as: [VKSavePhotoItem].self
                    ) { saveResult in
                        switch saveResult {
                        case .success(let photosList):
                            if let firstPhoto = photosList.first {
                                let att = "photo\(firstPhoto.ownerId)_\(firstPhoto.id)"
                                completion(.success(att))
                            } else {
                                completion(.failure(APIError.invalidResponse))
                            }
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } catch {
                    completion(.failure(APIError.decoding(error)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func repost(object: String,
                message: String = "",
                groupID: Int? = nil,
                asGroup: Bool = false,
                signed: Bool = false,
                completion: @escaping (Result<Int, Error>) -> Void) {
        struct VKRepostResponse: Decodable {
            let success: Int?
            let postId: Int?
            let prettyId: String?
            let repostsCount: Int?
            let likesCount: Int?

            enum CodingKeys: String, CodingKey {
                case success
                case postId
                case prettyId = "pretty_id"
                case repostsCount = "reposts_count"
                case likesCount = "likes_count"
            }
        }

        var params: [String: String] = ["object": object]
        if !message.isEmpty {
            params["message"] = message
        }
        if let groupID = groupID {
            params["group_id"] = String(groupID)
        }
        params["as_group"] = asGroup ? "1" : "0"
        params["signed"] = signed ? "1" : "0"

        APIClient.shared.call(
            method: "wall.repost",
            parameters: params,
            httpMethod: "POST",
            as: VKRepostResponse.self
        ) { result in
            switch result {
            case .success(let response):
                completion(.success(response.repostsCount ?? 1))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func mapVKFeed(_ response: VKFeedResponse) -> [Post] {
        let profiles = response.profiles ?? []
        let groups = response.groups ?? []
        let items = response.items ?? []
        
        return items.map { mapVKPost($0, profiles: profiles, groups: groups) }
    }
    
    private func mapVKPost(_ item: VKPost, profiles: [VKProfile], groups: [VKGroup]) -> Post {
        let itemSourceId = item.fromId ?? item.sourceId ?? 0
        let author = resolveUser(id: itemSourceId, profiles: profiles, groups: groups)

        let itemOwnerId = item.ownerId ?? item.sourceId ?? item.fromId ?? 0
        let wallOwner: User? = (itemOwnerId != 0 && itemOwnerId != itemSourceId)
            ? resolveUser(id: itemOwnerId, profiles: profiles, groups: groups)
            : nil

        // Форматирование времени
        let date = Date(timeIntervalSince1970: item.date ?? Date().timeIntervalSince1970)
        let timeAgo = date.timeAgoDescription()
        
        // Парсим вложения
        var localAttachments: [Attachment] = []
        if let atts = item.attachments {
            for att in atts {
                if att.type == "photo", let p = att.photo {
                    if let sizeUrl = findBestPhotoURL(p.sizes) {
                        localAttachments.append(.remoteImage(
                            url: sizeUrl,
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
            wallOwner: wallOwner,
            platform: item.postSource?.platform,
            timeAgo: timeAgo,
            text: item.text ?? "",
            hasImage: localAttachments.contains(where: { if case .image = $0 { return true } else if case .remoteImage = $0 { return true } else { return false } }),
            attachments: localAttachments,
            likes: item.likes?.count ?? 0,
            comments: item.comments?.count ?? 0,
            reposts: item.reposts?.count ?? 0,
            isLiked: (item.likes?.userLikes ?? 0) == 1,
            copyHistory: repostsList,
            isExplicit: item.isExplicit ?? false
        )
    }

    private func resolveUser(id: Int, profiles: [VKProfile], groups: [VKGroup]) -> User {
        if id > 0 {
            if let p = profiles.first(where: { ($0.id ?? 0) == id }) {
                return User(
                    uid: id,
                    username: p.screenName ?? "id\(id)",
                    displayName: "\(p.firstName ?? "") \(p.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                    avatarURL: p.photo100.flatMap { URL(string: $0) },
                    isOfficial: p.verified == 1
                )
            } else {
                return User(uid: id, username: "id\(id)", displayName: "Пользователь \(id)")
            }
        } else {
            let absId = abs(id)
            if let g = groups.first(where: { ($0.id ?? 0) == absId }) {
                return User(
                    uid: -absId,
                    username: g.screenName ?? "club\(absId)",
                    displayName: g.name ?? "Сообщество \(absId)",
                    avatarURL: g.photo100.flatMap { URL(string: $0) },
                    isGroup: true,
                    isOfficial: g.verified == 1
                )
            } else {
                return User(uid: -absId, username: "club\(absId)", displayName: "Сообщество \(absId)", isGroup: true)
            }
        }
    }
    
    private func findBestPhotoURL(_ sizes: [VKPhotoSize]?) -> String? {
        guard let sizes = sizes, !sizes.isEmpty else { return nil }
        
        if let match = sizes.first(where: { $0.type == "z" || $0.type == "y" || $0.type == "x" }) {
            return match.url ?? match.src
        }
        return sizes.last?.url ?? sizes.last?.src
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

struct VKFeedResponse: Decodable {
    let items: [VKPost]?
    let profiles: [VKProfile]?
    let groups: [VKGroup]?
    let nextFrom: String?

    enum CodingKeys: String, CodingKey {
        case items, profiles, groups
        case nextFrom
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try? container.decode([VKPost].self, forKey: .items)
        profiles = try? container.decode([VKProfile].self, forKey: .profiles)
        groups = try? container.decode([VKGroup].self, forKey: .groups)
        if let stringValue = try? container.decode(String.self, forKey: .nextFrom) {
            nextFrom = stringValue
        } else if let intValue = try? container.decode(Int.self, forKey: .nextFrom) {
            nextFrom = String(intValue)
        } else {
            nextFrom = nil
        }
    }
}

struct VKPost: Decodable {
    let id: Int?
    let sourceId: Int?
    let fromId: Int?
    let ownerId: Int?
    let date: Double?
    let text: String?
    let isExplicit: Bool?
    let postSource: VKPostSource?
    let likes: VKLikes?
    let comments: VKComments?
    let reposts: VKReposts?
    let attachments: [VKAttachment]?
    let copyHistory: [VKPost]?

    enum CodingKeys: String, CodingKey {
        case id
        case sourceId = "source_id"
        case sourceIdCamel = "sourceId"
        case fromId = "from_id"
        case fromIdCamel = "fromId"
        case ownerId = "owner_id"
        case ownerIdCamel = "ownerId"
        case date
        case text
        case isExplicit = "is_explicit"
        case isExplicitCamel = "isExplicit"
        case nsfw
        case postSource = "post_source"
        case postSourceCamel = "postSource"
        case likes
        case comments
        case reposts
        case attachments
        case copyHistory = "copy_history"
        case copyHistoryCamel = "copyHistory"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(Int.self, forKey: .id)
        sourceId = (try? container.decode(Int.self, forKey: .sourceId)) ?? (try? container.decode(Int.self, forKey: .sourceIdCamel))
        fromId = (try? container.decode(Int.self, forKey: .fromId)) ?? (try? container.decode(Int.self, forKey: .fromIdCamel))
        ownerId = (try? container.decode(Int.self, forKey: .ownerId)) ?? (try? container.decode(Int.self, forKey: .ownerIdCamel))
        date = try? container.decode(Double.self, forKey: .date)
        text = try? container.decode(String.self, forKey: .text)
        postSource = (try? container.decode(VKPostSource.self, forKey: .postSource)) ?? (try? container.decode(VKPostSource.self, forKey: .postSourceCamel))
        likes = try? container.decode(VKLikes.self, forKey: .likes)
        comments = try? container.decode(VKComments.self, forKey: .comments)
        reposts = try? container.decode(VKReposts.self, forKey: .reposts)
        attachments = try? container.decode([VKAttachment].self, forKey: .attachments)
        copyHistory = (try? container.decode([VKPost].self, forKey: .copyHistory)) ?? (try? container.decode([VKPost].self, forKey: .copyHistoryCamel))

        if let boolVal = (try? container.decode(Bool.self, forKey: .isExplicit)) ?? (try? container.decode(Bool.self, forKey: .isExplicitCamel)) ?? (try? container.decode(Bool.self, forKey: .nsfw)) {
            isExplicit = boolVal
        } else if let intVal = (try? container.decode(Int.self, forKey: .isExplicit)) ?? (try? container.decode(Int.self, forKey: .isExplicitCamel)) ?? (try? container.decode(Int.self, forKey: .nsfw)) {
            isExplicit = intVal == 1
        } else {
            isExplicit = false
        }
    }
}

struct VKPostSource: Decodable {
    let type: String?
    let platform: String?
}

struct VKLikes: Decodable {
    let count: Int?
    let userLikes: Int?
}

struct VKComments: Decodable {
    let count: Int?
}

struct VKReposts: Decodable {
    let count: Int?
}

struct VKAttachment: Decodable {
    let type: String
    let photo: VKPhotoAttachment?
    let video: VKVideoAttachment?
    let poll: VKPollAttachment?
    let doc: VKDocAttachment?
    let audio: VKAudioAttachment?
}

struct VKPhotoAttachment: Decodable {
    let id: Int?
    let ownerId: Int?
    let sizes: [VKPhotoSize]?
    let text: String?
    let likes: VKLikesInfo?
    let comments: VKCommentsInfo?
    let reposts: VKRepostsInfo?
}

struct VKPhotoSize: Decodable {
    let url: String?
    let src: String?
    let type: String?
}

struct VKVideoAttachment: Decodable {
    let id: Int?
    let ownerId: Int?
    let title: String?
    let duration: Int?
    let image: [VKVideoImage]?
    let player: String?
    let files: [String: String]?
    let likes: VKLikesInfo?
    let comments: VKCommentsInfo?
    let reposts: VKRepostsInfo?

    enum CodingKeys: String, CodingKey {
        case id, title, duration, image, player, files, ownerId, likes, comments, reposts
    }
}

struct VKVideoImage: Decodable {
    let url: String
    let width: Int?
    let height: Int?
}

struct VKPollAttachment: Decodable {
    let question: String?
    let answers: [VKPollAnswer]?
    let votes: Int?
}

struct VKPollAnswer: Decodable {
    let id: Int?
    let text: String?
    let votes: Int?
}

struct VKDocAttachment: Decodable {
    let title: String?
    let ext: String?
    let size: Int?
    let url: String?
}

struct VKAudioAttachment: Decodable {
    let artist: String?
    let title: String?
    let duration: Int?
}

struct VKProfile: Decodable {
    let id: Int?
    let firstName: String?
    let lastName: String?
    let screenName: String?
    let photo100: String?
    let verified: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case firstNameCamel = "firstName"
        case lastName = "last_name"
        case lastNameCamel = "lastName"
        case screenName = "screen_name"
        case screenNameCamel = "screenName"
        case photo100 = "photo_100"
        case photo100Camel = "photo100"
        case verified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(Int.self, forKey: .id)
        firstName = (try? container.decode(String.self, forKey: .firstName)) ?? (try? container.decode(String.self, forKey: .firstNameCamel))
        lastName = (try? container.decode(String.self, forKey: .lastName)) ?? (try? container.decode(String.self, forKey: .lastNameCamel))
        screenName = (try? container.decode(String.self, forKey: .screenName)) ?? (try? container.decode(String.self, forKey: .screenNameCamel))
        photo100 = (try? container.decode(String.self, forKey: .photo100)) ?? (try? container.decode(String.self, forKey: .photo100Camel))
        if let intVal = try? container.decode(Int.self, forKey: .verified) {
            verified = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .verified) {
            verified = boolVal ? 1 : 0
        } else {
            verified = nil
        }
    }
}

struct VKGroup: Decodable {
    let id: Int?
    let name: String?
    let screenName: String?
    let photo100: String?
    let verified: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case screenName = "screen_name"
        case screenNameCamel = "screenName"
        case photo100 = "photo_100"
        case photo100Camel = "photo100"
        case verified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(Int.self, forKey: .id)
        name = try? container.decode(String.self, forKey: .name)
        screenName = (try? container.decode(String.self, forKey: .screenName)) ?? (try? container.decode(String.self, forKey: .screenNameCamel))
        photo100 = (try? container.decode(String.self, forKey: .photo100)) ?? (try? container.decode(String.self, forKey: .photo100Camel))
        if let intVal = try? container.decode(Int.self, forKey: .verified) {
            verified = intVal
        } else if let boolVal = try? container.decode(Bool.self, forKey: .verified) {
            verified = boolVal ? 1 : 0
        } else {
            verified = nil
        }
    }
}

extension Date {
    func timeAgoDescription() -> String {
        OpenVKDateFormatter.formatRelative(self)
    }
}

struct VKLikesCountResponse: Decodable {
    let likes: Int?
}

struct VKUploadServerResponse: Decodable {
    let uploadUrl: String?
}

struct VKSavePhotoItem: Decodable {
    let id: Int
    let ownerId: Int
}

struct VKUploadResult: Decodable {
    let server: String
    let photo: String
    let hash: String
    
    enum CodingKeys: String, CodingKey {
        case server, photo, hash
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.photo = try container.decode(String.self, forKey: .photo)
        self.hash = try container.decode(String.self, forKey: .hash)
        
        if let serverInt = try? container.decode(Int.self, forKey: .server) {
            self.server = String(serverInt)
        } else {
            self.server = try container.decode(String.self, forKey: .server)
        }
    }
}
