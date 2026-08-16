//
//  Color+Extensions.swift
//  OpenVK for iOS
//
//  Акцентный цвет приложения
//

import SwiftUI

// MARK: - Accent color helpers

/// Возвращает цвет акцента по его отображаемому имени (из настроек).
func appAccentColor(for name: String) -> Color {
    switch name {
    case "Синий":
        return Color(red: 0.15, green: 0.45, blue: 0.85)
    case "Голубой":
        return Color(red: 0.20, green: 0.65, blue: 0.95)
    case "Розовый":
        return .pink
    case "Фиолетовый":
        return .purple
    case "Зеленый":
        return Color(red: 0.20, green: 0.75, blue: 0.40)
    case "Оранжевый":
        return .orange
    case "Красный":
        return .red
    default:
        return Color(red: 0.15, green: 0.45, blue: 0.85)
    }
}

extension Color {
    static var appAccent: Color {
        let name = UserDefaults.standard.string(forKey: "openvk.accent_color") ?? "Синий"
        return appAccentColor(for: name)
    }
}
