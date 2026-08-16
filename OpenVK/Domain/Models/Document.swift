//
//  Document.swift
//  OpenVK for iOS
//
//  Модель документа.
//

import Foundation

struct Document: Identifiable, Codable, Hashable {
    let id: Int
    let ownerID: Int
    let title: String
    let size: Int
    let ext: String
    let url: String
    let date: Double?
    let accessKey: String?

    var formattedSize: String {
        let kb = Double(size) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }

    var isOwn: Bool {
        let currentUID = AuthService.shared.currentUser?.uid ?? User.current.uid ?? 0
        return currentUID != 0 && ownerID == currentUID
    }
}

typealias AppDocument = Document
