//
//  AvatarRefreshService.swift
//  OpenVK for iOS
//

import Foundation

final class AvatarRefreshService {
    static let shared = AvatarRefreshService()

    private let refreshInterval: TimeInterval = 5 * 60
    private var timer: Timer?

    private init() {}

    func start() {
        guard AuthService.shared.isAuthenticated else { return }
        stop()

        AuthService.shared.refreshCurrentUser()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            AuthService.shared.refreshCurrentUser()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
