//
//  NavigationPanelItem.swift
//  OpenVK for iOS
//

import Foundation

import SwiftUI

struct NavigationPanelItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let icon: String
    let iconFilled: String
    let destinationType: NavigationDestinationType
    
    var isEnabled: Bool = true
    
    static func == (lhs: NavigationPanelItem, rhs: NavigationPanelItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Тип вкладки навигации
enum NavigationTabType: String, Codable, CaseIterable {
    case feed = "feed"
    case search = "search"
    case messages = "messages"
    case profile = "profile"
    case friends = "friends"
    case groups = "groups"
    case photos = "photos"
    case videos = "videos"
    case audio = "audio"
    case notes = "notes"
    case apps = "apps"
    case documents = "documents"
    case balance = "balance"
    case birthdays = "birthdays"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .feed: return "Лента"
        case .search: return "Поиск"
        case .messages: return "Сообщения"
        case .profile: return "Профиль"
        case .friends: return "Друзья"
        case .groups: return "Группы"
        case .photos: return "Фотографии"
        case .videos: return "Видеозаписи"
        case .audio: return "Аудиозаписи"
        case .notes: return "Заметки"
        case .apps: return "Приложения"
        case .documents: return "Документы"
        case .balance: return "Баланс"
        case .birthdays: return "Дни рождения"
        case .other: return "Прочее"
        }
    }
    
    var iconName: String {
        switch self {
        case .feed: return "house"
        case .search: return "magnifyingglass"
        case .messages: return "message"
        case .profile: return "person"
        case .friends: return "person.2"
        case .groups: return "person.3"
        case .photos: return "photo.on.rectangle"
        case .videos: return "play.rectangle"
        case .audio: return "music.note"
        case .notes: return "note.text"
        case .apps: return "square.grid.3x3"
        case .documents: return "doc.text"
        case .balance: return "rublesign.circle"
        case .birthdays: return "gift"
        case .other: return "square.grid.2x2"
        }
    }
    
    var iconFilledName: String {
        switch self {
        case .feed: return "house.fill"
        case .search: return "magnifyingglass"
        case .messages: return "message.fill"
        case .profile: return "person.fill"
        case .friends: return "person.2.fill"
        case .groups: return "person.3.fill"
        case .photos: return "photo.on.rectangle.fill"
        case .videos: return "play.rectangle.fill"
        case .audio: return "music.note"
        case .notes: return "note.text"
        case .apps: return "square.grid.3x3.fill"
        case .documents: return "doc.text.fill"
        case .balance: return "rublesign.circle.fill"
        case .birthdays: return "gift.fill"
        case .other: return "square.grid.2x2"
        }
    }
    
    var isAlwaysInPanel: Bool {
        return self == .other
    }
    
    var isMainTab: Bool {
        return [.feed, .search, .messages, .other].contains(self)
    }
}
