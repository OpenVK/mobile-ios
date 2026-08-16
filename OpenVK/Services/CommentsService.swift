//
//  CommentsService.swift
//  OpenVK for iOS
//

import Foundation

protocol CommentsServiceProtocol {
    func fetchComments(ownerID: Int, postID: Int, offset: Int, count: Int, completion: @escaping (Result<(comments: [Comment], count: Int), Error>) -> Void)
    func createComment(ownerID: Int, postID: Int, text: String, completion: @escaping (Result<Comment, Error>) -> Void)
    func toggleLike(commentID: Int, ownerID: Int, isLiked: Bool, completion: @escaping (Result<(isLiked: Bool, likesCount: Int), Error>) -> Void)
    func togglePostLike(ownerID: Int, postID: Int, isLiked: Bool, completion: @escaping (Result<(isLiked: Bool, likesCount: Int), Error>) -> Void)
    func editComment(commentID: Int, ownerID: Int, text: String, completion: @escaping (Result<Comment, Error>) -> Void)
    func deleteComment(commentID: Int, ownerID: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchMediaComments(type: String, ownerID: Int, mediaID: Int, offset: Int, count: Int, completion: @escaping (Result<(comments: [Comment], count: Int), Error>) -> Void)
    func createMediaComment(type: String, ownerID: Int, mediaID: Int, text: String, completion: @escaping (Result<Comment, Error>) -> Void)
}

final class CommentsService: CommentsServiceProtocol {

    static let shared = CommentsService()
    private let client: APIClientProtocol

    private init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    func fetchComments(ownerID: Int, postID: Int, offset: Int, count: Int, completion: @escaping (Result<(comments: [Comment], count: Int), Error>) -> Void) {
        let params: [String: String] = [
            "owner_id": "\(ownerID)",
            "post_id": "\(postID)",
            "need_likes": "1",
            "offset": "\(offset)",
            "count": "\(count)",
            "sort": "asc",
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,online_info,online"
        ]

        client.call(method: "wall.getComments", parameters: params, httpMethod: "GET", as: VKCommentsResponse.self) { result in
            switch result {
            case .success(let response):
                let profiles = response.profiles ?? []
                let groups = response.groups ?? []
                let comments = response.items.map { item -> Comment in
                    let author: User
                    if item.fromId > 0 {
                        if let p = profiles.first(where: { $0.id == item.fromId }) {
                            author = User(
                                uid: item.fromId,
                                username: p.screenName ?? "id\(item.fromId)",
                                displayName: "\(p.firstName ?? "") \(p.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                                avatarURL: p.photo100.flatMap { URL(string: $0) },
                                isOfficial: p.verified == 1
                            )
                        } else {
                            author = User(uid: item.fromId, username: "id\(item.fromId)", displayName: "Пользователь \(item.fromId)")
                        }
                    } else {
                        let absId = abs(item.fromId)
                        if let g = groups.first(where: { $0.id == absId }) {
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

                    let date = Date(timeIntervalSince1970: item.date)
                    let parsedAttachments = self.parseAttachments(item.attachments)
                    return Comment(
                        id: item.id,
                        postId: item.postId ?? 0,
                        fromId: item.fromId,
                        ownerId: item.ownerId ?? 0,
                        author: author,
                        text: item.text,
                        date: date,
                        likesCount: item.likes?.count ?? 0,
                        isLiked: (item.likes?.userLikes ?? 0) == 1,
                        attachments: parsedAttachments
                    )
                }
                completion(.success((comments: comments, count: response.count)))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func createComment(ownerID: Int, postID: Int, text: String, completion: @escaping (Result<Comment, Error>) -> Void) {
        let params: [String: String] = [
            "owner_id": "\(ownerID)",
            "post_id": "\(postID)",
            "message": text
        ]

        client.call(method: "wall.createComment", parameters: params, httpMethod: "POST", as: VKCreateCommentResponse.self) { result in
            switch result {
            case .success(let response):
                let user = AuthService.shared.currentUser ?? User.current
                let comment = Comment(
                    id: response.commentId,
                    postId: postID,
                    fromId: user.uid ?? 0,
                    ownerId: ownerID,
                    author: user,
                    text: text,
                    date: Date(),
                    likesCount: 0,
                    isLiked: false,
                    attachments: []
                )
                completion(.success(comment))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func parseAttachments(_ atts: [VKAttachment]?) -> [Attachment] {
        guard let atts = atts else { return [] }
        var result: [Attachment] = []
        for att in atts {
            if att.type == "photo", let p = att.photo {
                if let sizeUrl = findBestPhotoURL(p.sizes) {
                    result.append(.remoteImage(
                        url: sizeUrl,
                        id: p.id,
                        ownerID: p.ownerId,
                        likesCount: p.likes?.count ?? 0,
                        commentsCount: p.comments?.count ?? 0,
                        repostsCount: p.reposts?.count ?? 0,
                        isLiked: (p.likes?.userLikes ?? 0) == 1
                    ))
                } else {
                    result.append(.image(systemName: "photo"))
                }
            } else if att.type == "video", let v = att.video {
                let coverUrl = v.image?.last?.url ?? v.image?.first?.url ?? ""
                let directURL = v.files?["mp4_720"] ?? v.files?["mp4_480"] ?? v.files?["mp4_360"] ?? v.files?["mp4_240"] ?? v.player
                result.append(.remoteVideo(
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
            } else if att.type == "doc", let d = att.doc {
                if d.ext?.lowercased() == "gif" {
                    result.append(.gif(title: d.title ?? "GIF", url: d.url ?? ""))
                } else {
                    result.append(.document(title: d.title ?? "Документ", ext: d.ext ?? "", size: formatSize(d.size ?? 0), url: d.url ?? ""))
                }
            } else if att.type == "audio", let a = att.audio {
                result.append(.audio(artist: a.artist ?? "", title: a.title ?? "", duration: formatDuration(a.duration ?? 0)))
            }
        }
        return result
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

    func editComment(commentID: Int, ownerID: Int, text: String, completion: @escaping (Result<Comment, Error>) -> Void) {
        let params: [String: String] = [
            "comment_id": "\(commentID)",
            "owner_id": "\(ownerID)",
            "message": text
        ]

        client.call(method: "wall.editComment", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                let user = AuthService.shared.currentUser ?? User.current
                let comment = Comment(
                    id: commentID,
                    postId: 0,
                    fromId: user.uid ?? 0,
                    ownerId: ownerID,
                    author: user,
                    text: text,
                    date: Date(),
                    likesCount: 0,
                    isLiked: false,
                    attachments: []
                )
                completion(.success(comment))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func deleteComment(commentID: Int, ownerID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let params: [String: String] = [
            "comment_id": "\(commentID)",
            "owner_id": "\(ownerID)"
        ]

        client.call(method: "wall.deleteComment", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func togglePostLike(ownerID: Int, postID: Int, isLiked: Bool, completion: @escaping (Result<(isLiked: Bool, likesCount: Int), Error>) -> Void) {
        let method = isLiked ? "likes.delete" : "likes.add"
        let params: [String: String] = [
            "type": "post",
            "owner_id": "\(ownerID)",
            "item_id": "\(postID)"
        ]

        client.call(method: method, parameters: params, httpMethod: "POST", as: VKLikesCountResponse.self) { result in
            switch result {
            case .success(let response):
                completion(.success((isLiked: !isLiked, likesCount: response.likes ?? 0)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func toggleLike(commentID: Int, ownerID: Int, isLiked: Bool, completion: @escaping (Result<(isLiked: Bool, likesCount: Int), Error>) -> Void) {
        let method = isLiked ? "likes.delete" : "likes.add"
        let params: [String: String] = [
            "type": "comment",
            "owner_id": "\(ownerID)",
            "item_id": "\(commentID)"
        ]

        client.call(method: method, parameters: params, httpMethod: "POST", as: VKLikesCountResponse.self) { result in
            switch result {
            case .success(let response):
                completion(.success((isLiked: !isLiked, likesCount: response.likes ?? 0)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchMediaComments(type: String, ownerID: Int, mediaID: Int, offset: Int, count: Int, completion: @escaping (Result<(comments: [Comment], count: Int), Error>) -> Void) {
        let method = type == "photo" ? "photos.getComments" : "video.getComments"
        let idParam = type == "photo" ? "photo_id" : "video_id"
        let params: [String: String] = [
            "owner_id": "\(ownerID)",
            idParam: "\(mediaID)",
            "need_likes": "1",
            "offset": "\(offset)",
            "count": "\(count)",
            "sort": "asc",
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,online_info,online"
        ]

        client.call(method: method, parameters: params, httpMethod: "GET", as: VKCommentsResponse.self) { result in
            switch result {
            case .success(let response):
                let profiles = response.profiles ?? []
                let groups = response.groups ?? []
                let comments = response.items.map { item -> Comment in
                    let author: User
                    if item.fromId > 0 {
                        if let p = profiles.first(where: { $0.id == item.fromId }) {
                            author = User(
                                uid: item.fromId,
                                username: p.screenName ?? "id\(item.fromId)",
                                displayName: "\(p.firstName ?? "") \(p.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                                avatarURL: p.photo100.flatMap { URL(string: $0) },
                                isOfficial: p.verified == 1
                            )
                        } else {
                            author = User(uid: item.fromId, username: "id\(item.fromId)", displayName: "Пользователь \(item.fromId)")
                        }
                    } else {
                        let absId = abs(item.fromId)
                        if let g = groups.first(where: { $0.id == absId }) {
                            author = User(
                                uid: -absId,
                                username: g.screenName ?? "club\(absId)",
                                displayName: g.name ?? "Группа \(absId)",
                                avatarURL: g.photo100.flatMap { URL(string: $0) },
                                isGroup: true,
                                isOfficial: g.verified == 1
                            )
                        } else {
                            author = User(uid: -absId, username: "club\(absId)", displayName: "Группа \(absId)", isGroup: true)
                        }
                    }

                    let date = Date(timeIntervalSince1970: item.date)
                    let parsedAttachments = self.parseAttachments(item.attachments)
                    return Comment(
                        id: item.id,
                        postId: item.postId ?? 0,
                        fromId: item.fromId,
                        ownerId: item.ownerId ?? ownerID,
                        author: author,
                        text: item.text,
                        date: date,
                        likesCount: item.likes?.count ?? 0,
                        isLiked: (item.likes?.userLikes ?? 0) == 1,
                        attachments: parsedAttachments
                    )
                }
                completion(.success((comments: comments, count: response.count)))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func createMediaComment(type: String, ownerID: Int, mediaID: Int, text: String, completion: @escaping (Result<Comment, Error>) -> Void) {
        let method = type == "photo" ? "photos.createComment" : "video.createComment"
        let idParam = type == "photo" ? "photo_id" : "video_id"
        let params: [String: String] = [
            "owner_id": "\(ownerID)",
            idParam: "\(mediaID)",
            "message": text
        ]

        client.call(method: method, parameters: params, httpMethod: "POST", as: VKCreateCommentResponse.self) { result in
            switch result {
            case .success(let response):
                let user = AuthService.shared.currentUser ?? User.current
                let comment = Comment(
                    id: response.commentId,
                    postId: 0,
                    fromId: user.uid ?? 0,
                    ownerId: ownerID,
                    author: user,
                    text: text,
                    date: Date(),
                    likesCount: 0,
                    isLiked: false,
                    attachments: []
                )
                completion(.success(comment))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchLatestComment(ownerID: Int, postID: Int, completion: @escaping (Result<Comment?, Error>) -> Void) {
        let params: [String: String] = [
            "owner_id": "\(ownerID)",
            "post_id": "\(postID)",
            "need_likes": "1",
            "offset": "0",
            "count": "1",
            "sort": "desc",
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,online_info,online"
        ]

        client.call(method: "wall.getComments", parameters: params, httpMethod: "GET", as: VKCommentsResponse.self) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let profiles = response.profiles ?? []
                let groups = response.groups ?? []
                
                if let item = response.items.first {
                    let author: User
                    if item.fromId > 0 {
                        if let p = profiles.first(where: { $0.id == item.fromId }) {
                            author = User(
                                uid: item.fromId,
                                username: p.screenName ?? "id\(item.fromId)",
                                displayName: "\(p.firstName ?? "") \(p.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                                avatarURL: p.photo100.flatMap { URL(string: $0) },
                                isOfficial: p.verified == 1
                            )
                        } else {
                            author = User(uid: item.fromId, username: "id\(item.fromId)", displayName: "Пользователь \(item.fromId)")
                        }
                    } else {
                        let absId = abs(item.fromId)
                        if let g = groups.first(where: { $0.id == absId }) {
                            author = User(
                                uid: -absId,
                                username: g.screenName ?? "club\(absId)",
                                displayName: g.name ?? "Группа \(absId)",
                                avatarURL: g.photo100.flatMap { URL(string: $0) },
                                isGroup: true,
                                isOfficial: g.verified == 1
                            )
                        } else {
                            author = User(uid: -absId, username: "club\(absId)", displayName: "Группа \(absId)", isGroup: true)
                        }
                    }

                    let date = Date(timeIntervalSince1970: item.date)
                    let parsedAttachments = self.parseAttachments(item.attachments)
                    let comment = Comment(
                        id: item.id,
                        postId: item.postId ?? 0,
                        fromId: item.fromId,
                        ownerId: item.ownerId ?? 0,
                        author: author,
                        text: item.text,
                        date: date,
                        likesCount: item.likes?.count ?? 0,
                        isLiked: item.likes?.userLikes == 1,
                        attachments: parsedAttachments
                    )
                    completion(.success(comment))
                } else {
                    completion(.success(nil))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
