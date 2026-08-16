//
//  AppTab.swift
//  OpenVK for iOS
//

import Foundation

enum AppTab: Int, CaseIterable, Identifiable {
    case feed, search, messages, more

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .feed:     return "house"
        case .search:   return "magnifyingglass"
        case .messages: return "message"
        case .more:     return "square.grid.2x2"
        }
    }

    var iconFilled: String {
        switch self {
        case .feed:     return "house.fill"
        case .search:   return "magnifyingglass"
        case .messages: return "message.fill"
        case .more:     return "square.grid.2x2"
        }
    }

    var label: String {
        switch self {
        case .feed:     return "Лента"
        case .search:   return "Поиск"
        case .messages: return "Сообщения"
        case .more:     return "Прочее"
        }
    }
}
