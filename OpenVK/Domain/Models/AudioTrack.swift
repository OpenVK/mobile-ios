//
//  AudioTrack.swift
//  OpenVK for iOS
//
//  Модель аудиозаписи.
//

import SwiftUI

struct AudioTrack: Identifiable, Hashable {
    let id: UUID
    let vkID: Int?
    let ownerID: Int?
    let title: String
    let artist: String
    let duration: String
    let durationSeconds: Int?
    let url: String?
    let color: Color
    let systemName: String

    init(id: UUID = UUID(),
         vkID: Int? = nil,
         ownerID: Int? = nil,
         title: String,
         artist: String,
         duration: String,
         durationSeconds: Int? = nil,
         url: String? = nil,
         color: Color = .appAccent,
         systemName: String = "music.note") {
        self.id = id
        self.vkID = vkID
        self.ownerID = ownerID
        self.title = title
        self.artist = artist
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.url = url
        self.color = color
        self.systemName = systemName
    }
}
