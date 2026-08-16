//
//  AudioTrack.swift
//  OpenVK for iOS
//
//  Модель аудиозаписи.
//

import SwiftUI

struct AudioTrack: Identifiable {
    let id: UUID
    let title: String
    let artist: String
    let duration: String
    let color: Color
    let systemName: String

    init(id: UUID = UUID(),
         title: String,
         artist: String,
         duration: String,
         color: Color = .appAccent,
         systemName: String = "music.note") {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.color = color
        self.systemName = systemName
    }
}
