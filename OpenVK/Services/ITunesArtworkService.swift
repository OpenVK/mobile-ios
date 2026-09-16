//
//  ITunesArtworkService.swift
//  OpenVK for iOS
//
//  Сервис для поиска обложек треков и плейлистов через iTunes API
//

import Foundation
import UIKit

final class ITunesArtworkService {
    static let shared = ITunesArtworkService()

    private let memoryCache = NSCache<NSString, NSString>()
    private let userDefaults = UserDefaults.standard
    private let userDefaultsPrefix = "openvk_itunes_art_"
    private let urlSession: URLSession

    private var activeTasks: [String: Task<String?, Never>] = [:]
    private let lock = NSLock()

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        self.urlSession = URLSession(configuration: configuration)
    }

    func fetchTrackArtworkURL(artist: String, title: String) async -> String? {
        let cleanArtist = sanitizeQuery(artist)
        let cleanTitle = sanitizeQuery(title)
        guard !cleanArtist.isEmpty || !cleanTitle.isEmpty else { return nil }

        let cacheKey = "track_\(cleanArtist.lowercased())_\(cleanTitle.lowercased())"
        return await fetchArtwork(cacheKey: cacheKey) {
            let searchTerm = "\(cleanArtist) \(cleanTitle)".trimmingCharacters(in: .whitespacesAndNewlines)
            return await self.performSearch(term: searchTerm, entity: "song")
        }
    }

    func fetchPlaylistArtworkURL(title: String) async -> String? {
        let cleanTitle = sanitizeQuery(title)
        guard !cleanTitle.isEmpty else { return nil }

        let cacheKey = "playlist_\(cleanTitle.lowercased())"
        return await fetchArtwork(cacheKey: cacheKey) {
            return await self.performSearch(term: cleanTitle, entity: "album")
        }
    }

    func cachedTrackArtworkURL(artist: String, title: String) -> String? {
        let cleanArtist = sanitizeQuery(artist)
        let cleanTitle = sanitizeQuery(title)
        guard !cleanArtist.isEmpty || !cleanTitle.isEmpty else { return nil }

        let cacheKey = "track_\(cleanArtist.lowercased())_\(cleanTitle.lowercased())"
        return readFromCache(cacheKey: cacheKey)
    }

    func cachedPlaylistArtworkURL(title: String) -> String? {
        let cleanTitle = sanitizeQuery(title)
        guard !cleanTitle.isEmpty else { return nil }

        let cacheKey = "playlist_\(cleanTitle.lowercased())"
        return readFromCache(cacheKey: cacheKey)
    }

    private func readFromCache(cacheKey: String) -> String? {
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            let val = cached as String
            return val.isEmpty ? nil : val
        }

        if let persisted = userDefaults.string(forKey: userDefaultsPrefix + cacheKey) {
            memoryCache.setObject(persisted as NSString, forKey: cacheKey as NSString)
            return persisted.isEmpty ? nil : persisted
        }

        return nil
    }

    private func fetchArtwork(cacheKey: String, perform: @escaping () async -> String?) async -> String? {
        if let cached = readFromCache(cacheKey: cacheKey) {
            return cached
        }

        lock.lock()
        if let existingTask = activeTasks[cacheKey] {
            lock.unlock()
            return await existingTask.value
        }

        let task = Task<String?, Never> {
            let result = await perform()

            let cacheValue = result ?? ""
            self.memoryCache.setObject(cacheValue as NSString, forKey: cacheKey as NSString)
            self.userDefaults.set(cacheValue, forKey: self.userDefaultsPrefix + cacheKey)

            self.lock.lock()
            self.activeTasks.removeValue(forKey: cacheKey)
            self.lock.unlock()

            return result
        }

        activeTasks[cacheKey] = task
        lock.unlock()

        return await task.value
    }

    private func performSearch(term: String, entity: String) async -> String? {
        guard var components = URLComponents(string: "https://itunes.apple.com/search") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let searchResult = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            guard let first = searchResult.results.first else {
                return nil
            }

            // Извлекаем обложку и преобразуем к максимальному разрешению
            let rawURL = first.artworkUrl100 ?? first.artworkUrl60
            guard let artworkURL = rawURL else { return nil }

            return highResolutionArtworkURL(from: artworkURL)
        } catch {
            return nil
        }
    }

    private func highResolutionArtworkURL(from urlString: String) -> String {
        var highRes = urlString.replacingOccurrences(of: "100x100bb.jpg", with: "600x600bb.jpg")
        highRes = highRes.replacingOccurrences(of: "100x100bb.png", with: "600x600bb.png")
        highRes = highRes.replacingOccurrences(of: "60x60bb.jpg", with: "600x600bb.jpg")
        return highRes
    }

    private func sanitizeQuery(_ string: String) -> String {
        var clean = string
        clean = clean.replacingOccurrences(of: #"\[.*?\]"#, with: "", options: .regularExpression)
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean
    }
}

private struct ITunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [ITunesItem]
}

private struct ITunesItem: Decodable {
    let artworkUrl100: String?
    let artworkUrl60: String?
}
