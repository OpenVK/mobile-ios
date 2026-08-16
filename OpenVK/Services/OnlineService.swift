//
//  OnlineService.swift
//  OpenVK for iOS
//
//  Сервис поддержания статуса онлайн.
//

import Foundation
import SwiftUI

final class OnlineService: ObservableObject {

    static let shared = OnlineService()

    private var timer: Timer?
    private var isRunning = false
    private let pingInterval: TimeInterval = 180 // Каждые 3 минуты пока активно (на бэкенде OpenVK онлайн держится 5 мин)

    private init() {}

    func start() {
        guard AuthService.shared.isAuthenticated else { return }
        guard !isRunning else { return }
        isRunning = true
        
        sendSetOnline()
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.sendSetOnline()
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func sendSetOnline() {
        guard AuthService.shared.isAuthenticated else { return }
        
        APIClient.shared.call(
            method: "account.setOnline",
            parameters: [:],
            httpMethod: "GET",
            as: Int.self
        ) { result in
            switch result {
            case .success:
                #if DEBUG
                print("[OnlineService] account.setOnline sent successfully")
                #endif
            case .failure(let error):
                #if DEBUG
                print("[OnlineService] account.setOnline failed: \(error)")
                #endif
            }
        }
    }
}
