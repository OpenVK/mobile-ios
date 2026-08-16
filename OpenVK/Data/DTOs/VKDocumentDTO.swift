//
//  VKDocumentDTO.swift
//  OpenVK for iOS
//

import Foundation

struct VKDocumentResponse: Decodable {
    let count: Int?
    let items: [VKDocumentItem]?
}

struct VKDocumentItem: Decodable {
    let id: Int?
    let ownerId: Int?
    let title: String?
    let size: Int?
    let ext: String?
    let url: String?
    let date: Double?
    let accessKey: String?

    enum CodingKeys: String, CodingKey {
        case id, title, size, ext, url, date
        case ownerId    = "ownerId"
        case owner_id   = "owner_id"
        case user_id    = "user_id"
        case accessKey  = "accessKey"
        case access_key = "access_key"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)

        let oId = (try? container.decodeIfPresent(Int.self, forKey: .owner_id))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .ownerId))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .user_id))
        ownerId = oId

        title = try container.decodeIfPresent(String.self, forKey: .title)
        size  = try container.decodeIfPresent(Int.self, forKey: .size)
        ext   = try container.decodeIfPresent(String.self, forKey: .ext)
        url   = try container.decodeIfPresent(String.self, forKey: .url)
        date  = try container.decodeIfPresent(Double.self, forKey: .date)

        let aKey = (try? container.decodeIfPresent(String.self, forKey: .access_key))
            ?? (try? container.decodeIfPresent(String.self, forKey: .accessKey))
        accessKey = aKey
    }

    func toDocument() -> Document {
        Document(
            id: id ?? 0,
            ownerID: ownerId ?? 0,
            title: title ?? "Документ",
            size: size ?? 0,
            ext: ext ?? "",
            url: url ?? "",
            date: date,
            accessKey: accessKey
        )
    }

    func toAppDocument() -> Document { toDocument() }
}
