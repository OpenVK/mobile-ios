//
//  Comment.swift
//  OpenVK for iOS
//


import Foundation

struct Comment: Identifiable, Hashable {
    let id: Int
    let postId: Int
    let fromId: Int
    let ownerId: Int
    let author: User
    let text: String
    let date: Date
    let likesCount: Int
    var isLiked: Bool
    let attachments: [Attachment]
    var attachmentPreviewLabels: [String] = []

    var previewText: String {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ([message] + attachmentPreviewLabels)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct VKCommentsResponse: Decodable {
    let count: Int
    let items: [VKCommentItem]
    let profiles: [VKProfile]?
    let groups: [VKGroup]?
    let currentLevelCount: Int?
    let canPost: Bool?

    private enum CodingKeys: String, CodingKey {
        case count, items, profiles, groups, currentLevelCount, canPost
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = try container.decode(Int.self, forKey: .count)
        items = try container.decode([VKCommentItem].self, forKey: .items)
        profiles = try container.decodeIfPresent([VKProfile].self, forKey: .profiles)
        groups = try container.decodeIfPresent([VKGroup].self, forKey: .groups)
        currentLevelCount = try container.decodeIfPresent(Int.self, forKey: .currentLevelCount)
        // OpenVK returns an integer for regular posts and a Bool in some responses.
        if let value = try? container.decode(Bool.self, forKey: .canPost) {
            canPost = value
        } else {
            canPost = try container.decodeIfPresent(Int.self, forKey: .canPost).map { $0 == 1 }
        }
    }
}

struct VKCommentItem: Decodable {
    let id: Int
    let fromId: Int
    let date: Double
    let text: String
    let postId: Int?
    let ownerId: Int?
    let likes: VKCommentLikes?
    let attachments: [VKAttachment]?

    var attachmentPreviewLabels: [String] {
        (attachments ?? []).map { attachment in
            switch attachment.type {
            case "photo": return "[Фотография]"
            case "video": return "[Видео]"
            case "sticker": return "[Стикер]"
            case "audio": return "[Аудиозапись]"
            case "audio_message": return "[Голосовое сообщение]"
            case "doc": return attachment.doc?.ext?.lowercased() == "gif" ? "[GIF]" : "[Документ]"
            case "poll": return "[Опрос]"
            case "note": return "[Заметка]"
            case "link": return "[Ссылка]"
            case "wall": return "[Запись]"
            case "gift": return "[Подарок]"
            default: return "[Вложение]"
            }
        }
    }
}

struct VKCommentLikes: Decodable {
    let count: Int
    let userLikes: Int
    let canLike: Int?
}

struct VKCreateCommentResponse: Decodable {
    let commentId: Int
}

struct VKDefaultResponse: Decodable {
    let response: Int
}
