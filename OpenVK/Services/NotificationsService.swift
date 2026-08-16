//
//  NotificationsService.swift
//  OpenVK for iOS
//
//  Сервис для работы с уведомлениями OpenVK.
//

import Foundation

protocol NotificationsServiceProtocol {
    func fetchNotifications(archived: Bool, offset: Int, count: Int, completion: @escaping (Result<[AppNotification], Error>) -> Void)
    func markAsRead(completion: @escaping (Result<Void, Error>) -> Void)
    func fetchGifts(completion: @escaping (Result<[VKUserGift], Error>) -> Void)
}

extension NotificationsServiceProtocol {
    func fetchNotifications(archived: Bool, offset: Int = 0, count: Int = 20, completion: @escaping (Result<[AppNotification], Error>) -> Void) {
        fetchNotifications(archived: archived, offset: offset, count: count, completion: completion)
    }
}

final class NotificationsService: NotificationsServiceProtocol {
    
    static let shared = NotificationsService()
    
    private init() {}
    
    func fetchNotifications(archived: Bool, offset: Int = 0, count: Int = 20, completion: @escaping (Result<[AppNotification], Error>) -> Void) {
        let params: [String: String] = [
            "count": "\(count)",
            "offset": "\(offset)",
            "archived": archived ? "1" : "0"
        ]
        
        APIClient.shared.call(
            method: "notifications.get",
            parameters: params,
            httpMethod: "GET",
            as: VKNotificationsResponse.self
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let items = response.items ?? []
                let profiles = response.profiles ?? []
                let groups = response.groups ?? []
                
                let mapped = items.compactMap { item in
                    self.mapVKNotification(item, profiles: profiles, groups: groups, isRead: archived)
                }
                completion(.success(mapped))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func markAsRead(completion: @escaping (Result<Void, Error>) -> Void) {
        APIClient.shared.call(
            method: "notifications.markAsViewed",
            parameters: [:],
            httpMethod: "POST",
            as: Int.self
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func fetchGifts(completion: @escaping (Result<[VKUserGift], Error>) -> Void) {
        APIClient.shared.call(
            method: "gifts.get",
            parameters: ["count": "15"],
            httpMethod: "GET",
            as: VKGiftsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                completion(.success(response.items ?? []))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func mapVKNotification(_ item: VKNotificationItem, profiles: [VKProfile], groups: [VKGroup], isRead: Bool) -> AppNotification? {
        guard let typeString = item.type else { return nil }
        
        let notificationType: AppNotification.NotificationType
        switch typeString {
        case "like_post", "like_comment", "like_photo", "like_video":
            notificationType = .like
        case "copy_post":
            notificationType = .repost
        case "comment_post", "comment_photo", "comment_video", "comment_note", "comment_topic":
            notificationType = .comment
        case "friendRequest", "follow":
            notificationType = .friendRequest
        case "mention", "mention_comment_video", "mention_comment_photo", "mention_comment_note", "mention_comments":
            notificationType = .mention
        case "wall":
            notificationType = .wallPost
        case "sent_gift":
            notificationType = .gift
        case "voices_transfer":
            notificationType = .voicesTransfer
        case "up_rating":
            notificationType = .ratingUp
        case "make_you_admin":
            notificationType = .makeAdmin
        default:
            notificationType = .comment
        }
        
        var actorId: Int? = nil
        if let feedback = item.feedback {
            if let fromId = feedback.fromId {
                actorId = fromId
            } else if let id = feedback.id {
                actorId = id
            } else if let firstItem = feedback.items?.first {
                actorId = firstItem.fromId
            }
        }
        
        if actorId == nil, let parentId = item.parent?.id {
            actorId = parentId
        }
        
        let sourceId = actorId ?? 0
        
        let author: User
        if sourceId > 0 {
            if let p = profiles.first(where: { ($0.id ?? 0) == sourceId }) {
                author = User(
                    uid: sourceId,
                    username: p.screenName ?? "id\(sourceId)",
                    displayName: "\(p.firstName ?? "") \(p.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                    avatarURL: p.photo100.flatMap { URL(string: $0) },
                    isOfficial: p.verified == 1
                )
            } else {
                author = User(uid: sourceId, username: "id\(sourceId)", displayName: "Пользователь \(sourceId)")
            }
        } else if sourceId < 0 {
            let absId = abs(sourceId)
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
        } else {
            author = User(username: "unknown", displayName: "Пользователь")
        }
        
        let dateVal = Date(timeIntervalSince1970: item.date ?? Date().timeIntervalSince1970)
        let timeAgo = dateVal.timeAgoDescription()
        
        var previewText: String? = nil
        var ratingVal: String? = nil
        var targetPostID: Int? = nil
        var targetPostOwnerID: Int? = nil
        
        let parentOwner = item.parent?.toId ?? item.parent?.ownerId ?? item.parent?.fromId
        let feedbackOwner = item.feedback?.toId ?? item.feedback?.ownerId ?? item.feedback?.fromId

        if notificationType == .like || notificationType == .repost {
            previewText = item.parent?.text ?? item.parent?.title
            targetPostID = item.parent?.id
            targetPostOwnerID = parentOwner
        } else if notificationType == .comment {
            previewText = item.parent?.text ?? item.parent?.title
            targetPostID = item.parent?.id
            targetPostOwnerID = parentOwner
        } else if notificationType == .mention {
            previewText = item.feedback?.text ?? item.parent?.text ?? item.parent?.title
            targetPostID = item.feedback?.id ?? item.parent?.id
            targetPostOwnerID = feedbackOwner ?? parentOwner
        } else if notificationType == .wallPost {
            previewText = item.feedback?.text
            targetPostID = item.feedback?.id
            targetPostOwnerID = feedbackOwner
        } else if notificationType == .gift {
            previewText = item.feedback?.text
        } else if notificationType == .voicesTransfer {
            previewText = item.feedback?.text
        } else if notificationType == .makeAdmin {
            previewText = item.parent?.name ?? item.parent?.title ?? item.parent?.text
        } else if notificationType == .ratingUp {
            if let countStr = item.parent?.count {
                let parts = countStr.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                if let firstPart = parts.first {
                    let val = String(firstPart)
                    ratingVal = val.contains("%") ? val : "\(val)%"
                }
                if parts.count > 1 {
                    previewText = String(parts[1])
                }
            }
        }
        
        return AppNotification(
            id: UUID(),
            type: notificationType,
            user: author,
            postTextPreview: previewText,
            createdAt: timeAgo,
            isRead: isRead,
            ratingValue: ratingVal,
            date: dateVal,
            targetPostID: targetPostID,
            targetPostOwnerID: targetPostOwnerID
        )
    }
}

struct VKNotificationsResponse: Decodable {
    let items: [VKNotificationItem]?
    let profiles: [VKProfile]?
    let groups: [VKGroup]?
}

struct VKNotificationItem: Decodable {
    let type: String?
    let date: Double?
    let parent: VKNotificationParent?
    let feedback: VKNotificationFeedback?
}

struct VKNotificationParent: Decodable {
    let id: Int?
    let toId: Int?
    let fromId: Int?
    let ownerId: Int?
    let text: String?
    let title: String?
    let name: String?
    let count: String?
    
    enum CodingKeys: String, CodingKey {
        case id, toId, fromId, ownerId, text, title, name, count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        toId = try container.decodeIfPresent(Int.self, forKey: .toId)
        fromId = try container.decodeIfPresent(Int.self, forKey: .fromId)
        ownerId = try container.decodeIfPresent(Int.self, forKey: .ownerId)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        
        if let countInt = try? container.decodeIfPresent(Int.self, forKey: .count) {
            count = String(countInt)
        } else if let countStr = try? container.decodeIfPresent(String.self, forKey: .count) {
            count = countStr
        } else {
            count = nil
        }
    }
}

struct VKNotificationFeedback: Decodable {
    let id: Int?
    let fromId: Int?
    let toId: Int?
    let ownerId: Int?
    let text: String?
    let items: [VKNotificationFeedbackItem]?
}

struct VKNotificationFeedbackItem: Decodable {
    let fromId: Int?
}

struct VKGiftsResponse: Decodable {
    let count: Int
    let items: [VKUserGift]?
}

struct VKUserGift: Decodable {
    let id: Int
    let fromId: Int?
    let message: String?
    let date: Double?
    let privacy: Int?
    let gift: VKGiftDetails?
}

struct VKGiftDetails: Decodable {
    let id: Int
    let thumb256: String?
    let thumb96: String?
    let thumb48: String?
}
