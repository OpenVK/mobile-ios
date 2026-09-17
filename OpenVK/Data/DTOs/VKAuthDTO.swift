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

    var instanceDisplayName: String {
        guard instanceOption == .custom else {
            return instanceOption.displayName
        }

        let host = customInstanceHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            return instanceOption.displayName
        }

        let normalizedHost = host.hasPrefix("http://") || host.hasPrefix("https://")
            ? host
            : "https://\(host)"
        if let url = URL(string: normalizedHost), let urlHost = url.host {
            let port = url.port.map { ":\($0)" } ?? ""
            return urlHost + port
        }
        return host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
