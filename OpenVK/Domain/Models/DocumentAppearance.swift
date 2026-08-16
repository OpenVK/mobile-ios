//
//  DocumentAppearance.swift
//  OpenVK for iOS
//
//  UI-атрибуты документа (иконка, цвет) — отдельно от доменной модели.

import SwiftUI

extension Document {
    /// SF Symbol для типа файла.
    var iconName: String {
        let cleanExt = ext.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch cleanExt {
        case "pdf":
            return "doc.text.fill"
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "webp", "bmp", "heic":
            return "photo.fill"
        case "mp3", "ogg", "wav", "flac", "m4a", "aac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv", "webm":
            return "play.rectangle.fill"
        case "swift", "py", "js", "html", "css", "php", "cpp", "c", "json", "xml":
            return "chevron.left.forward.slash.chevron.right"
        default:
            return "doc.fill"
        }
    }

    /// Цвет иконки для типа файла.
    var iconColor: Color {
        let cleanExt = ext.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch cleanExt {
        case "pdf":
            return .red
        case "zip", "rar", "7z", "tar", "gz":
            return .orange
        case "jpg", "jpeg", "png", "gif", "webp", "bmp", "heic":
            return .cyan
        case "mp3", "ogg", "wav", "flac", "m4a", "aac":
            return .blue
        case "mp4", "mov", "avi", "mkv", "webm":
            return .purple
        case "swift", "py", "js", "html", "css", "php", "cpp", "c", "json", "xml":
            return .green
        default:
            return .gray
        }
    }
}
