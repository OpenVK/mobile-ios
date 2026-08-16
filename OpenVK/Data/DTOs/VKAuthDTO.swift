//
//  VKAuthDTO.swift
//  OpenVK for iOS
//
//  Data Transfer Objects для авторизации и аккаунта.
//

import Foundation

// MARK: - Counters & votes

struct VKCountersResponse: Decodable {
    let friends: Int?
    let notifications: Int?
    let messages: Int?
}

struct VKBalanceResponse: Decodable {
    let votes: Int
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidCredentials
    case network

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Неверный e-mail или пароль"
        case .network:            return "Проблема с подключением"
        }
    }
}

struct AuthAccount: Codable, Identifiable, Hashable {
    var id: String { user.username }
    let user: User
    let token: String
    let instanceOption: InstanceOption
    let customInstanceHost: String
}
