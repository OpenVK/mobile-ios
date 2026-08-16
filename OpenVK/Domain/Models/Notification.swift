//
//  Notification.swift
//  OpenVK for iOS
//
//  Модель уведомлений.
//

import Foundation

typealias AppNotification = AppNotificationModel

struct AppNotificationModel: Identifiable, Hashable {
    enum NotificationType: String, Codable {
        case like
        case comment
        case friendRequest
        case repost
        case mention
        case wallPost
        case gift
        case voicesTransfer
        case ratingUp
        case makeAdmin
    }

    let id: UUID
    let type: NotificationType
    let user: User
    let postTextPreview: String? // Текст поста или сам комментарий
    let createdAt: String        // Форматированное время
    var isRead: Bool
    let ratingValue: String?     // На сколько повышен рейтинг
    let giftImageURL: URL?       // Ссылка на изображение подарка
    let date: Date               // Оригинальная дата уведомления
    let targetPostID: Int?       // ID поста для перехода
    let targetPostOwnerID: Int?  // ID владельца стены поста

    init(id: UUID = UUID(),
         type: NotificationType,
         user: User,
         postTextPreview: String? = nil,
         createdAt: String,
         isRead: Bool = false,
         ratingValue: String? = nil,
         giftImageURL: URL? = nil,
         date: Date = Date(),
         targetPostID: Int? = nil,
         targetPostOwnerID: Int? = nil) {
        self.id = id
        self.type = type
        self.user = user
        self.postTextPreview = postTextPreview
        self.createdAt = createdAt
        self.isRead = isRead
        self.ratingValue = ratingValue
        self.giftImageURL = giftImageURL
        self.date = date
        self.targetPostID = targetPostID
        self.targetPostOwnerID = targetPostOwnerID
    }
}
