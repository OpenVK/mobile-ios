//
//  SupportersService.swift
//  OpenVK for iOS
//
//  Сервис поддержки: тестеры и донатеры.
//

import Foundation
import Combine

struct Supporter: Codable, Identifiable, Hashable {
    let name: String?
    let nick: String?
    let icon: String?
    let amount: String?
    let message: String?
    let profiles: [String]?

    var id: String { "\(name ?? "")|\(nick ?? "")|\(amount ?? "")" }

    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return nick ?? "—"
    }
}

struct SupportersData: Codable {
    let testers: [Supporter]?
    let donors: [Supporter]?
}

final class SupportersService: ObservableObject {

    static let shared = SupportersService()

    @Published private(set) var testers: [Supporter] = []
    @Published private(set) var donors: [Supporter] = []

    private let sourceURL = URL(string: "https://files.nikanikoo.com/ovk-ios/supporters.json")!
    private let ttl: TimeInterval = 3 * 60 * 60 // 3 часа
    private let lastFetchKey = "openvk.supporters_last_fetch"

    private var screenNameLookup: [String: Supporter] = [:]

    private lazy var cacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("openvk_supporters.json")
    }()

    private init() {
        loadCached()
    }

    func refreshIfNeeded(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastFetchDate) >= ttl else { return }
        Task {
            await fetch()
        }
    }

    func supporter(screenName: String?) -> Supporter? {
        guard let name = screenName?.lowercased() else { return nil }
        return screenNameLookup[name]
    }

    func iconURL(screenName: String?) -> URL? {
        guard let icon = supporter(screenName: screenName)?.icon, !icon.isEmpty else { return nil }
        return URL(string: icon)
    }

    private var lastFetchDate: Date {
        UserDefaults.standard.object(forKey: lastFetchKey) as? Date ?? .distantPast
    }

    private func loadCached() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        apply(data)
    }

    private func fetch() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: sourceURL)
            try? data.write(to: cacheURL, options: .atomic)
            UserDefaults.standard.set(Date(), forKey: lastFetchKey)
            apply(data)
        } catch {
        }
    }

    private func apply(_ data: Data) {
        guard let response = try? JSONDecoder().decode(SupportersData.self, from: data) else { return }
        DispatchQueue.main.async {
            self.testers = response.testers ?? []
            self.donors = response.donors ?? []
            var lookup: [String: Supporter] = [:]
            for supporter in self.testers + self.donors {
                for profile in supporter.profiles ?? [] {
                    guard let screen = profile.split(separator: "/").last.map({ String($0) }) else { continue }
                    let cleaned = screen
                        .lowercased()
                        .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                    if !cleaned.isEmpty {
                        lookup[cleaned] = supporter
                    }
                }
            }
            self.screenNameLookup = lookup
        }
    }
}