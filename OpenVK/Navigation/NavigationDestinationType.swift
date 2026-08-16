//
//  NavigationDestinationType.swift
//  OpenVK for iOS
//
//  Типы целевых представлений для навигации.
//

import Foundation
import SwiftUI

/// Тип целевого представления для навигации
enum NavigationDestinationType: String, Codable, CaseIterable {
    case feed
    case search
    case messages
    case profile
    case friends
    case groups
    case photos
    case videos
    case audio
    case notes
    case apps
    case documents
    case balance
    case birthdays
    case more
    
    /// Отображаемое имя
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
        case .more: return "Прочее"
        }
    }
    
    /// Имена иконок
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
        case .more: return "square.grid.2x2"
        }
    }
    
    /// Имя заполненной иконки
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
        case .more: return "square.grid.2x2"
        }
    }
    
    var isMainTab: Bool {
        switch self {
        case .feed, .search, .messages, .more:
            return true
        default:
            return false
        }
    }
    
    var isAlwaysInPanel: Bool {
        return self == .more
    }
    
    func getView(tabBarHeight: CGFloat) -> AnyView {
        switch self {
        case .feed:
            return AnyView(EmptyView())
        case .search:
            return AnyView(EmptyView())
        case .messages:
            return AnyView(EmptyView())
        case .profile:
            return AnyView(EmptyView())
        case .friends:
            return AnyView(EmptyView())
        case .groups:
            return AnyView(EmptyView())
        case .photos:
            return AnyView(EmptyView())
        case .videos:
            return AnyView(EmptyView())
        case .audio:
            return AnyView(EmptyView())
        case .notes:
            return AnyView(EmptyView())
        case .apps:
            return AnyView(EmptyView())
        case .documents:
            return AnyView(EmptyView())
        case .balance:
            return AnyView(EmptyView())
        case .birthdays:
            return AnyView(EmptyView())
        case .more:
            return AnyView(EmptyView())
        }
    }
    
    var canBeInPanel: Bool {
        switch self {
        case .feed, .search, .messages, .profile, .friends, .groups, .photos, .videos, .audio, .notes, .apps, .documents, .balance, .birthdays:
            return true
        case .more:
            return false
        }
    }
}
