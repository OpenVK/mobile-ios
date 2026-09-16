//
//  AudioService.swift
//  OpenVK for iOS
//
//  OpenVK audio API, local audio cache and global player.
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import CryptoKit

struct AudioPlaylist: Identifiable, Hashable {
    let id: Int
    let ownerID: Int
    let title: String
    let description: String
    let size: Int
    let length: Int
    let coverURL: String?
}

enum AudioCacheLimit: Int64, CaseIterable, Identifiable {
    case mb256 = 268435456
    case mb512 = 536870912
    case gb1 = 1073741824
    case gb2 = 2147483648
    case unlimited = -1

    var id: Int64 { rawValue }

    var title: String {
        switch self {
        case .mb256: return "256 МБ"
        case .mb512: return "512 МБ"
        case .gb1: return "1 ГБ"
        case .gb2: return "2 ГБ"
        case .unlimited: return "Без лимита"
        }
    }
}

extension Notification.Name {
    static let openvkAudioLibraryDidChange = Notification.Name("openvk.audioLibraryDidChange")
    static let openvkAudioLibraryStateDidChange = Notification.Name("openvk.audioLibraryStateDidChange")
}

enum AudioLibraryMutationError: LocalizedError {
    case missingIdentifiers

    var errorDescription: String? {
        switch self {
        case .missingIdentifiers:
            return "У аудиозаписи отсутствует ID, поэтому изменить коллекцию нельзя."
        }
    }
}

final class AudioLibraryMembership: ObservableObject {
    static let shared = AudioLibraryMembership()

    @Published private(set) var pendingKeys: Set<String> = []
    private var states: [String: Bool] = [:]

    private init() {}

    func canMutate(_ track: AudioTrack) -> Bool {
        key(for: track) != nil
    }

    func isAdded(_ track: AudioTrack) -> Bool {
        guard let key = key(for: track) else { return false }
        return states[key] ?? false
    }

    func isPending(_ track: AudioTrack) -> Bool {
        guard let key = key(for: track) else { return false }
        return pendingKeys.contains(key)
    }

    func seed(_ track: AudioTrack, added: Bool) {
        guard let key = key(for: track), !pendingKeys.contains(key) else { return }
        if states[key] != added {
            objectWillChange.send()
            states[key] = added
        }
    }

    func seedAdded(_ tracks: [AudioTrack]) {
        var changed = false
        for track in tracks {
            guard let key = key(for: track), !pendingKeys.contains(key) else { continue }
            if states[key] != true {
                states[key] = true
                changed = true
            }
        }
        if changed {
            objectWillChange.send()
        }
    }

    func toggle(_ track: AudioTrack) {
        setAdded(!isAdded(track), for: track)
    }

    func setAdded(_ added: Bool, for track: AudioTrack, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let key = key(for: track) else {
            completion?(.failure(AudioLibraryMutationError.missingIdentifiers))
            return
        }
        guard !pendingKeys.contains(key) else { return }

        let previous = states[key] ?? false
        objectWillChange.send()
        states[key] = added
        NotificationCenter.default.post(name: .openvkAudioLibraryStateDidChange, object: track)
        var pending = pendingKeys
        pending.insert(key)
        pendingKeys = pending

        AudioService.shared.setTrackAdded(added, track: track) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                var pending = self.pendingKeys
                pending.remove(key)
                self.pendingKeys = pending

                switch result {
                case .success:
                    NotificationCenter.default.post(name: .openvkAudioLibraryStateDidChange, object: track)
                    NotificationCenter.default.post(name: .openvkAudioLibraryDidChange, object: track)
                    completion?(.success(()))
                case .failure(let error):
                    self.objectWillChange.send()
                    self.states[key] = previous
                    NotificationCenter.default.post(name: .openvkAudioLibraryStateDidChange, object: track)
                    completion?(.failure(error))
                }
            }
        }
    }

    private func key(for track: AudioTrack) -> String? {
        guard let ownerID = track.ownerID, let vkID = track.vkID else { return nil }
        let accountID = AuthService.shared.currentUser?.uid ?? 0
        return "\(accountID):\(ownerID)_\(vkID)"
    }
}

final class AudioService {
    static let shared = AudioService()

    private init() {}

    func getTracks(
        ownerID: Int,
        playlistID: Int? = nil,
        offset: Int = 0,
        count: Int = 100,
        artworkURL: String? = nil,
        completion: @escaping (Result<[AudioTrack], APIError>) -> Void
    ) {
        var params: [String: String] = [
            "owner_id": "\(ownerID)",
            "offset": "\(offset)",
            "count": "\(count)",
            "need_user": "1"
        ]
        if let playlistID = playlistID {
            params["album_id"] = "\(playlistID)"
        }

        APIClient.shared.call(
            method: "audio.get",
            parameters: params,
            httpMethod: "GET",
            as: AudioItemsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let tracks = (response.items ?? []).map {
                    Self.mapTrack($0, fallbackOwnerID: ownerID, artworkURL: artworkURL)
                }
                completion(.success(tracks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getPlaylists(
        ownerID: Int,
        offset: Int = 0,
        count: Int = 100,
        completion: @escaping (Result<[AudioPlaylist], APIError>) -> Void
    ) {
        APIClient.shared.call(
            method: "audio.getAlbums",
            parameters: [
                "owner_id": "\(ownerID)",
                "offset": "\(offset)",
                "count": "\(count)"
            ],
            httpMethod: "GET",
            as: AudioPlaylistsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                completion(.success((response.items ?? []).compactMap(Self.mapPlaylist)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getPopularTracks(
        offset: Int = 0,
        count: Int = 100,
        completion: @escaping (Result<[AudioTrack], APIError>) -> Void
    ) {
        APIClient.shared.call(
            method: "audio.getPopular",
            parameters: [
                "offset": "\(offset)",
                "count": "\(count)"
            ],
            httpMethod: "GET",
            as: AudioItemsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let tracks = (response.items ?? [])
                    .filter(Self.isValidCatalogItem)
                    .map { Self.mapTrack($0, fallbackOwnerID: nil, artworkURL: nil) }
                completion(.success(tracks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func searchTracks(
        query: String,
        offset: Int = 0,
        count: Int = 100,
        completion: @escaping (Result<[AudioTrack], APIError>) -> Void
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success([]))
            return
        }

        APIClient.shared.call(
            method: "audio.search",
            parameters: [
                "q": trimmed,
                "sort": "2",
                "offset": "\(offset)",
                "count": "\(count)"
            ],
            httpMethod: "GET",
            as: AudioItemsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let tracks = (response.items ?? [])
                    .filter(Self.isValidCatalogItem)
                    .map { Self.mapTrack($0, fallbackOwnerID: nil, artworkURL: nil) }
                completion(.success(Self.rankSearchResults(tracks, query: trimmed)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func searchPlaylists(
        query: String,
        offset: Int = 0,
        count: Int = 25,
        completion: @escaping (Result<[AudioPlaylist], APIError>) -> Void
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success([]))
            return
        }

        APIClient.shared.call(
            method: "audio.searchAlbums",
            parameters: [
                "q": trimmed,
                "offset": "\(offset)",
                "limit": "\(count)"
            ],
            httpMethod: "GET",
            as: AudioPlaylistsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                completion(.success((response.items ?? []).compactMap(Self.mapPlaylist)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func isValidCatalogItem(_ item: AudioItemDTO) -> Bool {
        if item.ready == false || item.withdrawn == true {
            return false
        }

        // OpenVK reports unprocessed/problematic audio as a ~1 second item.
        // Such entries cannot be played normally and should not pollute
        // Popular or global search results.
        return (item.duration ?? 0) > 1
    }

    func setTrackAdded(
        _ added: Bool,
        track: AudioTrack,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let audioID = track.vkID, let ownerID = track.ownerID else {
            completion(.failure(AudioLibraryMutationError.missingIdentifiers))
            return
        }

        APIClient.shared.call(
            method: added ? "audio.add" : "audio.delete",
            parameters: [
                "audio_id": "\(audioID)",
                "owner_id": "\(ownerID)"
            ],
            httpMethod: "POST",
            as: AudioMutationResponse.self
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func rankSearchResults(_ tracks: [AudioTrack], query: String) -> [AudioTrack] {
        let normalizedQuery = normalizeSearchText(query)
        guard !normalizedQuery.isEmpty else { return tracks }

        return tracks.enumerated()
            .map { index, track in
                let relevance = searchRelevance(track, query: normalizedQuery)
                // audio.search(sort: 2) already comes from the server in listens-descending order.
                // Keep a small rank bonus so popularity breaks ties without beating a much better text match.
                let popularityBonus = Double(max(0, 100 - index)) * 0.18
                return (track: track, score: relevance + popularityBonus, serverRank: index)
            }
            .sorted {
                if abs($0.score - $1.score) > 0.001 { return $0.score > $1.score }
                return $0.serverRank < $1.serverRank
            }
            .map(\.track)
    }

    private static func searchRelevance(_ track: AudioTrack, query: String) -> Double {
        let title = normalizeSearchText(track.title)
        let artist = normalizeSearchText(track.artist)
        let combined = "\(artist) \(title)"

        if title == query { return 100 }
        if combined == query { return 98 }
        if title.hasPrefix(query) { return 90 }
        if title.contains(query) { return 82 }
        if artist == query { return 78 }
        if artist.hasPrefix(query) { return 72 }
        if artist.contains(query) { return 66 }
        if combined.contains(query) { return 62 }

        let queryTokens = query.split(separator: " ").map(String.init)
        guard !queryTokens.isEmpty else { return 0 }
        let matched = queryTokens.filter { combined.contains($0) }.count
        let coverage = Double(matched) / Double(queryTokens.count)
        return coverage * 58
    }

    private static func normalizeSearchText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .joined(separator: " ")
    }

    private static func mapTrack(_ item: AudioItemDTO, fallbackOwnerID: Int?, artworkURL: String?) -> AudioTrack {
        let duration = max(0, item.duration ?? 0)
        let track = AudioTrack(
            vkID: item.id ?? item.aid,
            ownerID: item.ownerID ?? fallbackOwnerID,
            title: item.title?.isEmpty == false ? item.title! : "Аудиозапись",
            artist: item.artist?.isEmpty == false ? item.artist! : "Неизвестный исполнитель",
            duration: formatDuration(duration),
            durationSeconds: duration,
            url: item.url,
            artworkURL: artworkURL,
            systemName: "music.note"
        )
        if let added = item.added {
            AudioLibraryMembership.shared.seed(track, added: added)
        }
        return track
    }

    private static func mapPlaylist(_ item: AudioPlaylistDTO) -> AudioPlaylist? {
        guard let id = item.id else { return nil }
        return AudioPlaylist(
            id: id,
            ownerID: item.ownerID ?? 0,
            title: item.title?.isEmpty == false ? item.title! : "Плейлист",
            description: item.description ?? "",
            size: item.size ?? 0,
            length: item.length ?? 0,
            coverURL: item.coverURL
        )
    }

    private static func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    static func sanitizeArtworkURL(_ string: String?) -> String? {
        guard var raw = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if raw.hasPrefix("//") {
            raw = "https:" + raw
        }
        let lower = raw.lowercased()
        if lower.contains("song.jpg") ||
           lower.contains("camera_200") ||
           lower.hasPrefix("/assets/") ||
           lower.contains("packages/static") {
            return nil
        }
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return raw
    }
}

private struct AudioItemsResponse: Decodable {
    let count: Int?
    let items: [AudioItemDTO]?
}

private struct AudioItemDTO: Decodable {
    let id: Int?
    let aid: Int?
    let ownerID: Int?
    let artist: String?
    let title: String?
    let duration: Int?
    let url: String?
    let manifest: String?
    let added: Bool?
    let ready: Bool?
    let withdrawn: Bool?

    enum CodingKeys: String, CodingKey {
        case id, aid, artist, title, duration, url, manifest, added, ready, withdrawn
        case ownerID = "owner_id"
        case ownerIDCamel = "ownerId"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decode(Int.self, forKey: .id)
        aid = try? c.decode(Int.self, forKey: .aid)
        ownerID = (try? c.decode(Int.self, forKey: .ownerID)) ?? (try? c.decode(Int.self, forKey: .ownerIDCamel))
        artist = try? c.decode(String.self, forKey: .artist)
        title = try? c.decode(String.self, forKey: .title)
        duration = try? c.decode(Int.self, forKey: .duration)
        url = try? c.decode(String.self, forKey: .url)
        manifest = try? c.decode(String.self, forKey: .manifest)
        added = Self.decodeBool(c, key: .added)
        ready = Self.decodeBool(c, key: .ready)
        withdrawn = Self.decodeBool(c, key: .withdrawn)
    }

    private static func decodeBool(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Bool? {
        if let value = try? c.decode(Bool.self, forKey: key) { return value }
        if let value = try? c.decode(Int.self, forKey: key) { return value != 0 }
        return nil
    }
}

private struct AudioMutationResponse: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if (try? container.decode(Int.self)) != nil { return }
        if (try? container.decode(String.self)) != nil { return }
        if (try? container.decode(Bool.self)) != nil { return }
        throw DecodingError.typeMismatch(
            AudioMutationResponse.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported audio mutation response")
        )
    }
}

private struct AudioPlaylistsResponse: Decodable {
    let count: Int?
    let items: [AudioPlaylistDTO]?
}

private struct AudioPlaylistDTO: Decodable {
    let id: Int?
    let ownerID: Int?
    let title: String?
    let description: String?
    let size: Int?
    let length: Int?
    let coverURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, size, length
        case ownerID = "owner_id"
        case ownerIDCamel = "ownerId"
        case coverURL = "cover_url"
        case coverURLCamel = "coverUrl"
        case thumb, photo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decode(Int.self, forKey: .id)
        ownerID = (try? c.decode(Int.self, forKey: .ownerID)) ?? (try? c.decode(Int.self, forKey: .ownerIDCamel))
        title = try? c.decode(String.self, forKey: .title)
        description = try? c.decode(String.self, forKey: .description)
        size = try? c.decode(Int.self, forKey: .size)
        length = try? c.decode(Int.self, forKey: .length)

        let rawCover = (try? c.decode(String.self, forKey: .coverURL)) ?? (try? c.decode(String.self, forKey: .coverURLCamel))
        let thumbCover = (try? c.decode(AudioPlaylistThumbDTO.self, forKey: .thumb))?.bestPhotoURL
            ?? (try? c.decode(AudioPlaylistThumbDTO.self, forKey: .photo))?.bestPhotoURL
            ?? (try? c.decode(String.self, forKey: .photo))
        coverURL = AudioService.sanitizeArtworkURL(rawCover) ?? AudioService.sanitizeArtworkURL(thumbCover)
    }
}

private struct AudioPlaylistThumbDTO: Decodable {
    let photo34: String?
    let photo68: String?
    let photo135: String?
    let photo270: String?
    let photo300: String?
    let photo600: String?
    let photo1200: String?

    enum CodingKeys: String, CodingKey {
        case photo34 = "photo_34"
        case photo68 = "photo_68"
        case photo135 = "photo_135"
        case photo270 = "photo_270"
        case photo300 = "photo_300"
        case photo600 = "photo_600"
        case photo1200 = "photo_1200"
    }

    var bestPhotoURL: String? {
        photo600 ?? photo300 ?? photo270 ?? photo1200 ?? photo135 ?? photo68 ?? photo34
    }
}

final class AudioCacheService {
    static let shared = AudioCacheService()

    private let fileManager = FileManager.default
    private let stateQueue = DispatchQueue(label: "openvk.audio-cache.state")
    private var waiters: [String: [(Result<URL, Error>) -> Void]] = [:]
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private let limitKey = "openvk.audioCacheLimitBytes"

    private lazy var cacheDirectory: URL = {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent("openvk_audio_cache", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private init() {}

    var cacheLimit: AudioCacheLimit {
        get {
            guard let number = UserDefaults.standard.object(forKey: limitKey) as? NSNumber else {
                return .mb512
            }
            return AudioCacheLimit(rawValue: number.int64Value) ?? .mb512
        }
        set {
            UserDefaults.standard.set(NSNumber(value: newValue.rawValue), forKey: limitKey)
            trimToLimit()
        }
    }

    func cachedURL(for track: AudioTrack) -> URL? {
        guard let remoteURL = usableRemoteURL(for: track) else { return nil }
        let destination = destinationURL(for: track, remoteURL: remoteURL)
        guard fileManager.fileExists(atPath: destination.path) else { return nil }
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
        return destination
    }

    func cache(_ track: AudioTrack, completion: ((Result<URL, Error>) -> Void)? = nil) {
        if let cached = cachedURL(for: track) {
            if let completion = completion {
                DispatchQueue.main.async { completion(.success(cached)) }
            }
            return
        }

        guard let remoteURL = usableRemoteURL(for: track) else {
            if let completion = completion {
                DispatchQueue.main.async { completion(.failure(AudioPlaybackError.unavailableURL)) }
            }
            return
        }

        let key = cacheKey(for: track, remoteURL: remoteURL)
        let callback: (Result<URL, Error>) -> Void = completion ?? { _ in }

        stateQueue.async { [weak self] in
            guard let self = self else { return }
            if self.waiters[key] != nil {
                self.waiters[key]?.append(callback)
                return
            }
            self.waiters[key] = [callback]

            let task = URLSession.shared.downloadTask(with: remoteURL) { [weak self] temporaryURL, response, error in
                guard let self = self else { return }
                let result: Result<URL, Error>

                if let error = error {
                    result = .failure(error)
                } else if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    result = .failure(AudioPlaybackError.httpStatus(http.statusCode))
                } else if let temporaryURL = temporaryURL {
                    let destination = self.destinationURL(for: track, remoteURL: remoteURL)
                    do {
                        if self.fileManager.fileExists(atPath: destination.path) {
                            try self.fileManager.removeItem(at: destination)
                        }
                        try self.fileManager.moveItem(at: temporaryURL, to: destination)
                        try? self.fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
                        self.trimToLimit(preserving: [destination])
                        result = .success(destination)
                    } catch {
                        result = .failure(error)
                    }
                } else {
                    result = .failure(AudioPlaybackError.downloadFailed)
                }

                self.stateQueue.async {
                    self.tasks.removeValue(forKey: key)
                    let callbacks = self.waiters.removeValue(forKey: key) ?? []
                    DispatchQueue.main.async {
                        callbacks.forEach { $0(result) }
                    }
                }
            }
            self.tasks[key] = task
            task.resume()
        }
    }

    func prefetch(_ tracks: [AudioTrack]) {
        guard !tracks.isEmpty else { return }

        // cachedURL() touches the filesystem. Keep neighbor prefetching away
        // from the main thread so queue/shuffle controls react immediately.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            tracks.forEach { self.cache($0, completion: nil) }
        }
    }

    func totalCacheSizeBytes() -> Int64 {
        directorySize(cacheDirectory)
    }

    func totalCacheSizeString() -> String {
        ByteCountFormatter.string(fromByteCount: totalCacheSizeBytes(), countStyle: .file)
    }

    func clear() {
        stateQueue.sync {
            tasks.values.forEach { $0.cancel() }
            tasks.removeAll()
            waiters.removeAll()

            guard let files = try? fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { return }
            files.forEach { try? fileManager.removeItem(at: $0) }
        }
    }

    func trimToLimit() {
        trimToLimit(preserving: [])
    }

    private func trimToLimit(preserving protectedURLs: Set<URL>) {
        let limit = cacheLimit.rawValue
        guard limit >= 0 else { return }

        stateQueue.async { [weak self] in
            guard let self = self else { return }
            guard var files = try? self.fileManager.contentsOfDirectory(
                at: self.cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            var total = self.directorySize(self.cacheDirectory)
            guard total > limit else { return }

            files.sort {
                let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhs < rhs
            }

            for file in files where total > limit {
                if protectedURLs.contains(file) { continue }
                let size = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                try? self.fileManager.removeItem(at: file)
                total -= size
            }
        }
    }

    func usableRemoteURL(for track: AudioTrack) -> URL? {
        guard let raw = track.url,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }

        // OpenVK can intentionally return this file when direct audio URLs are disabled.
        if url.path.lowercased().hasSuffix("/audio/nomusic.mp3") || url.lastPathComponent.lowercased() == "nomusic.mp3" {
            return nil
        }
        return url
    }

    private func destinationURL(for track: AudioTrack, remoteURL: URL) -> URL {
        let key = cacheKey(for: track, remoteURL: remoteURL)
        let ext = remoteURL.pathExtension.isEmpty ? "audio" : remoteURL.pathExtension
        return cacheDirectory.appendingPathComponent("\(key).\(ext)")
    }

    private func cacheKey(for track: AudioTrack, remoteURL: URL) -> String {
        let identity = "\(track.ownerID ?? 0):\(track.vkID ?? 0):\(remoteURL.absoluteString)"
        let digest = SHA256.hash(data: Data(identity.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return files.reduce(0) { partial, file in
            partial + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
}

enum AudioRepeatMode: Int, CaseIterable {
    case off
    case all
    case one

    var systemImage: String {
        self == .one ? "repeat.1" : "repeat"
    }
}

enum AudioPlaybackError: LocalizedError {
    case unavailableURL
    case downloadFailed
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .unavailableURL:
            return "Аудиозапись недоступна для прямого воспроизведения."
        case .downloadFailed:
            return "Не удалось загрузить аудиозапись."
        case .httpStatus(let code):
            return "Сервер вернул ошибку HTTP \(code)."
        }
    }
}

struct AudioQueueEntry: Identifiable {
    let queueIndex: Int
    let track: AudioTrack

    var id: Int {
        queueIndex
    }
}

final class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()

    @Published private(set) var queue: [AudioTrack] = []
    @Published private(set) var currentTrack: AudioTrack?
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var isPreparing = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var errorMessage: String?
    @Published var isExpanded = false
    @Published var isOverlayHidden = false
    @Published var shuffleEnabled = false
    @Published var repeatMode: AudioRepeatMode = .off
    @Published var crossfadeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(crossfadeEnabled, forKey: "openvk.crossfade_enabled")
        }
    }
    @Published var crossfadeDuration: TimeInterval = 3
    @Published private(set) var isCrossfading = false

    var upcomingQueue: [AudioQueueEntry] {
        guard let index = currentIndex, queue.indices.contains(index), queue.count > 1 else { return [] }

        var indices = Array((index + 1)..<queue.count)
        if repeatMode == .all, index > 0 {
            indices.append(contentsOf: 0..<index)
        }

        let slice = indices.prefix(150)
        return slice.map { AudioQueueEntry(queueIndex: $0, track: queue[$0]) }
    }

    private var player = AVPlayer()
    private var crossfadePlayer = AVPlayer()
    private let cache = AudioCacheService.shared
    private var sourceQueue: [AudioTrack] = []
    private var timeObserver: Any?
    private var playbackToken = UUID()
    private var artworkTask: URLSessionDataTask?
    private var loadedArtworkKey: String?
    private var loadedArtwork: MPMediaItemArtwork?
    private var failedTrackKeys: Set<String> = []
    private var crossfadeTimer: DispatchWorkItem?
    private var crossfadeTimeObserver: Any?

    private lazy var placeholderArtwork: MPMediaItemArtwork = {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.secondarySystemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let configuration = UIImage.SymbolConfiguration(pointSize: 178, weight: .medium)
            if let symbol = UIImage(systemName: "music.note", withConfiguration: configuration)?
                .withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal) {
                let symbolSize = symbol.size
                let rect = CGRect(
                    x: (size.width - symbolSize.width) / 2,
                    y: (size.height - symbolSize.height) / 2,
                    width: symbolSize.width,
                    height: symbolSize.height
                )
                symbol.draw(in: rect)
            }
        }
        return MPMediaItemArtwork(boundsSize: size) { _ in image }
    }()

    private override init() {
        crossfadeEnabled = UserDefaults.standard.bool(forKey: "openvk.crossfade_enabled")
        super.init()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            guard !self.isCrossfading else { return }
            let value = CMTimeGetSeconds(time)
            if value.isFinite { self.currentTime = max(0, value) }
            if let item = self.player.currentItem {
                let itemDuration = CMTimeGetSeconds(item.duration)
                if itemDuration.isFinite && itemDuration > 0 {
                    self.duration = itemDuration
                } else if let expected = self.currentTrack?.durationSeconds {
                    self.duration = Double(expected)
                }
            }
            self.checkCrossfadeTrigger()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlay(_:)),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemNewErrorLogEntry(_:)),
            name: .AVPlayerItemNewErrorLogEntry,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountDidChange),
            name: .openvkAccountDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterrupted(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioLibraryStateDidChange),
            name: .openvkAudioLibraryStateDidChange,
            object: nil
        )

        setupRemoteCommands()
        syncRemoteCommandState()
    }

    deinit {
        artworkTask?.cancel()
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let observer = crossfadeTimeObserver {
            crossfadePlayer.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }

    func play(track: AudioTrack, in newQueue: [AudioTrack]) {
        if isSameTrack(track, currentTrack) {
            togglePlayPause()
            return
        }

        failedTrackKeys.removeAll()

        var resolvedQueue = newQueue.isEmpty ? [track] : newQueue
        var selectedIndex = resolvedQueue.firstIndex(where: { isSameTrack($0, track) })
        if selectedIndex == nil {
            resolvedQueue.append(track)
            selectedIndex = resolvedQueue.count - 1
        }
        guard let selectedIndex = selectedIndex else { return }

        sourceQueue = resolvedQueue
        if shuffleEnabled, resolvedQueue.count > 1 {
            let selectedTrack = resolvedQueue[selectedIndex]
            var remaining = resolvedQueue.enumerated()
                .filter { $0.offset != selectedIndex }
                .map(\.element)
            remaining.shuffle()
            queue = [selectedTrack] + remaining
            currentIndex = 0
        } else {
            queue = resolvedQueue
            currentIndex = selectedIndex
        }

        guard let index = currentIndex else { return }
        syncRemoteCommandState()
        prepareAndPlay(index: index)
    }

    func playQueueItem(at index: Int) {
        guard queue.indices.contains(index) else { return }
        failedTrackKeys.removeAll()
        prepareAndPlay(index: index)
    }

    func togglePlayPause() {
        guard currentTrack != nil else { return }
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        guard currentTrack != nil else { return }
        activateAudioSession()
        player.play()
        isPlaying = true
        isPreparing = false
        updateNowPlayingInfo()
        syncRemoteCommandState()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
        syncRemoteCommandState()
        deactivateAudioSession()
    }

    func next(userInitiated: Bool = true, loopAtEnd: Bool = false) {
        guard !queue.isEmpty, let index = currentIndex else { return }

        if !userInitiated && repeatMode == .one {
            seek(to: 0)
            resume()
            return
        }

        if isCrossfading {
            finalizeCrossfade()
            return
        }

        let nextIndex = index + 1
        if nextIndex < queue.count {
            prepareAndPlay(index: nextIndex, skipFailed: !userInitiated)
        } else if repeatMode == .all || loopAtEnd {
            prepareAndPlay(index: 0, skipFailed: !userInitiated)
        } else {
            finishQueue()
        }
    }

    func previous(forcePrevious: Bool = false) {
        guard !queue.isEmpty, let index = currentIndex else { return }
        if !forcePrevious && currentTime > 4 {
            seek(to: 0)
            resume()
            return
        }

        completeCrossfade()

        let previousIndex = index - 1
        if previousIndex >= 0 {
            prepareAndPlay(index: previousIndex)
        } else if repeatMode == .all || forcePrevious {
            prepareAndPlay(index: max(0, queue.count - 1))
        } else {
            seek(to: 0)
            resume()
        }
    }

    func seek(to seconds: Double) {
        let upper = duration > 0 ? duration : seconds
        let clamped = min(max(0, seconds), max(0, upper - 0.1))
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        currentTime = clamped
        updateNowPlayingInfo()
    }

    func toggleShuffle() {
        setShuffleEnabled(!shuffleEnabled)
    }

    func setShuffleEnabled(_ enabled: Bool) {
        guard shuffleEnabled != enabled else {
            syncRemoteCommandState()
            return
        }

        shuffleEnabled = enabled
        guard let current = currentTrack, let index = currentIndex else {
            syncRemoteCommandState()
            return
        }

        if enabled, queue.count > 1 {
            // Preserve playback history and the current item in-place.
            // Only the still-unplayed tail is shuffled, which avoids rebuilding
            // the whole queue and guarantees no repeats inside one shuffle pass.
            let firstUpcomingIndex = index + 1
            if firstUpcomingIndex < queue.count {
                var updatedQueue = queue
                var upcoming = Array(updatedQueue[firstUpcomingIndex...])
                upcoming.shuffle()
                updatedQueue.replaceSubrange(firstUpcomingIndex..<updatedQueue.count, with: upcoming)
                queue = updatedQueue
            }
            currentIndex = index
        } else if !enabled, !sourceQueue.isEmpty {
            queue = sourceQueue
            currentIndex = queue.firstIndex(where: { isSameTrack($0, current) })
        }

        prefetchNeighbors()
        syncRemoteCommandState()
        updateNowPlayingInfo()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: setRepeatMode(.all)
        case .all: setRepeatMode(.one)
        case .one: setRepeatMode(.off)
        }
    }

    func setRepeatMode(_ mode: AudioRepeatMode) {
        repeatMode = mode
        syncRemoteCommandState()
        updateNowPlayingInfo()
    }

    func stop() {
        playbackToken = UUID()
        artworkTask?.cancel()
        artworkTask = nil
        loadedArtwork = nil
        loadedArtworkKey = nil
        crossfadeTimer?.cancel()
        crossfadeTimer = nil
        if let observer = crossfadeTimeObserver {
            crossfadePlayer.removeTimeObserver(observer)
            crossfadeTimeObserver = nil
        }
        crossfadePlayer.pause()
        crossfadePlayer.replaceCurrentItem(with: nil)
        player.pause()
        player.replaceCurrentItem(with: nil)
        player.volume = Float(1.0)
        sourceQueue = []
        queue = []
        currentTrack = nil
        currentIndex = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        isPreparing = false
        isExpanded = false
        isCrossfading = false
        errorMessage = nil
        failedTrackKeys.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        syncRemoteCommandState()
        deactivateAudioSession()
    }

    private func prepareAndPlay(index: Int, skipFailed: Bool = false) {
        guard queue.indices.contains(index) else { return }
        let track = queue[index]
        let key = trackKey(track)

        if skipFailed && failedTrackKeys.contains(key) {
            let nextIndex = index + 1
            if nextIndex < queue.count {
                prepareAndPlay(index: nextIndex, skipFailed: true)
            } else if repeatMode == .all {
                prepareAndPlay(index: 0, skipFailed: true)
            } else {
                finishQueue()
            }
            return
        }

        currentIndex = index
        currentTrack = track
        currentTime = 0
        duration = Double(track.durationSeconds ?? 0)
        isPreparing = true
        isPlaying = false
        errorMessage = nil
        loadedArtwork = nil
        loadedArtworkKey = nil

        let token = UUID()
        playbackToken = token
        updateNowPlayingInfo(loadArtwork: true)
        syncRemoteCommandState()

        if let cached = cache.cachedURL(for: track) {
            beginPlayback(track: track, url: cached, token: token)
            return
        }

        if let remoteURL = cache.usableRemoteURL(for: track) {
            beginPlayback(track: track, url: remoteURL, token: token)
            cache.cache(track, completion: nil)
        } else {
            isPreparing = false
            errorMessage = AudioPlaybackError.unavailableURL.localizedDescription
            updateNowPlayingInfo()
            syncRemoteCommandState()
            deactivateAudioSession()
            failedTrackKeys.insert(key)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.next(loopAtEnd: true)
            }
        }
    }

    private func beginPlayback(track: AudioTrack, url: URL, token: UUID) {
        guard playbackToken == token, isSameTrack(track, currentTrack) else { return }
        completeCrossfade()
        activateAudioSession()
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.volume = Float(1.0)
        player.play()
        isPreparing = false
        isPlaying = true
        updateNowPlayingInfo()
        syncRemoteCommandState()
        prefetchNeighbors()
    }

    private func prefetchNeighbors() {
        guard let index = currentIndex, !queue.isEmpty else { return }
        var neighbors: [AudioTrack] = []
        if index > 0 { neighbors.append(queue[index - 1]) }
        if index + 1 < queue.count { neighbors.append(queue[index + 1]) }
        cache.prefetch(neighbors)
    }

    private func finishQueue() {
        player.pause()
        isPlaying = false
        isPreparing = false
        if duration > 0 { currentTime = duration }
        updateNowPlayingInfo()
        syncRemoteCommandState()
        deactivateAudioSession()
    }

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
        }
    }

    private func checkCrossfadeTrigger() {
        guard crossfadeEnabled,
              !isCrossfading,
              isPlaying,
              let nextIndex = nextTrackIndex(),
              duration > 0,
              duration - currentTime <= crossfadeDuration else { return }
        beginCrossfade(to: nextIndex)
    }

    private func nextTrackIndex() -> Int? {
        guard let index = currentIndex, !queue.isEmpty else { return nil }
        let nextIndex = index + 1
        if nextIndex < queue.count {
            return nextIndex
        } else if repeatMode == .all {
            return 0
        }
        return nil
    }

    private func beginCrossfade(to nextIndex: Int) {
        guard queue.indices.contains(nextIndex) else { return }
        let nextTrack = queue[nextIndex]
        guard let remoteURL = cache.usableRemoteURL(for: nextTrack) else { return }

        let nextItem = AVPlayerItem(url: cache.cachedURL(for: nextTrack) ?? remoteURL)
        crossfadePlayer.replaceCurrentItem(with: nextItem)
        crossfadePlayer.volume = Float(0)
        crossfadePlayer.play()
        isCrossfading = true

        if let existing = crossfadeTimeObserver {
            crossfadePlayer.removeTimeObserver(existing)
        }
        crossfadeTimeObserver = crossfadePlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self, self.isCrossfading else { return }
            let value = CMTimeGetSeconds(time)
            if value.isFinite { self.currentTime = max(0, value) }
            if let item = self.crossfadePlayer.currentItem {
                let itemDuration = CMTimeGetSeconds(item.duration)
                if itemDuration.isFinite && itemDuration > 0 {
                    self.duration = itemDuration
                } else if let expected = self.currentTrack?.durationSeconds {
                    self.duration = Double(expected)
                }
            }
        }

        currentIndex = nextIndex
        currentTrack = nextTrack
        currentTime = 0
        duration = Double(nextTrack.durationSeconds ?? 0)
        updateNowPlayingInfo(loadArtwork: true)
        syncRemoteCommandState()

        let fadeDuration = min(crossfadeDuration, duration - currentTime)
        let fadeSteps = 10
        let stepInterval = fadeDuration / Double(fadeSteps)

        var currentStep = 0
        let timer = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            currentStep += 1
            let progress = Double(currentStep) / Double(fadeSteps)
            self.player.volume = Float(max(0, 1.0 - progress))
            self.crossfadePlayer.volume = Float(min(1.0, progress))
            if currentStep < fadeSteps {
                DispatchQueue.main.asyncAfter(deadline: .now() + stepInterval) { [weak self] in
                    guard let self = self, let timer = self.crossfadeTimer else { return }
                    timer.perform()
                }
            }
        }
        crossfadeTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + stepInterval) { [weak self] in
            guard let self = self, let timer = self.crossfadeTimer else { return }
            timer.perform()
        }
    }

    private func finalizeCrossfade() {
        guard isCrossfading else {
            completeCrossfade()
            return
        }

        crossfadeTimer?.cancel()
        crossfadeTimer = nil

        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = crossfadeTimeObserver {
            crossfadePlayer.removeTimeObserver(observer)
            crossfadeTimeObserver = nil
        }

        crossfadePlayer.volume = Float(1.0)
        swap(&player, &crossfadePlayer)

        crossfadePlayer.pause()
        crossfadePlayer.replaceCurrentItem(with: nil)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            guard !self.isCrossfading else { return }
            let value = CMTimeGetSeconds(time)
            if value.isFinite { self.currentTime = max(0, value) }
            if let item = self.player.currentItem {
                let itemDuration = CMTimeGetSeconds(item.duration)
                if itemDuration.isFinite && itemDuration > 0 {
                    self.duration = itemDuration
                } else if let expected = self.currentTrack?.durationSeconds {
                    self.duration = Double(expected)
                }
            }
            self.checkCrossfadeTrigger()
        }

        currentTime = CMTimeGetSeconds(player.currentTime())
        if let item = player.currentItem {
            let itemDuration = CMTimeGetSeconds(item.duration)
            duration = itemDuration.isFinite && itemDuration > 0 ? itemDuration : Double(currentTrack?.durationSeconds ?? 0)
        } else {
            duration = Double(currentTrack?.durationSeconds ?? 0)
        }
        isPreparing = false
        isPlaying = true
        isCrossfading = false
        errorMessage = nil
        updateNowPlayingInfo()
        syncRemoteCommandState()
        prefetchNeighbors()
    }

    private func completeCrossfade() {
        crossfadeTimer?.cancel()
        crossfadeTimer = nil
        if let observer = crossfadeTimeObserver {
            crossfadePlayer.removeTimeObserver(observer)
            crossfadeTimeObserver = nil
        }
        crossfadePlayer.pause()
        crossfadePlayer.replaceCurrentItem(with: nil)
        player.volume = Float(1.0)
        crossfadePlayer.volume = Float(1.0)
        isCrossfading = false
    }

    @objc private func playerItemFailedToPlay(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let item = notification.object as? AVPlayerItem,
                  item === self.player.currentItem,
                  let track = self.currentTrack else { return }
            self.handlePlaybackError(for: track)
        }
    }

    @objc private func playerItemNewErrorLogEntry(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let item = notification.object as? AVPlayerItem,
                  item === self.player.currentItem,
                  let errorLog = item.errorLog(),
                  let lastEvent = errorLog.events.last,
                  lastEvent.errorStatusCode != 0,
                  let track = self.currentTrack else { return }
            self.handlePlaybackError(for: track)
        }
    }

    private func handlePlaybackError(for track: AudioTrack) {
        let key = trackKey(track)
        failedTrackKeys.insert(key)
        errorMessage = "Ошибка воспроизведения"
        isPreparing = false
        isPlaying = false
        player.pause()
        updateNowPlayingInfo()
        syncRemoteCommandState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.next(loopAtEnd: true)
        }
    }

    private func setupRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()

        commands.playCommand.isEnabled = true
        commands.playCommand.addTarget { [weak self] _ in
            guard self?.currentTrack != nil else { return .noSuchContent }
            DispatchQueue.main.async { self?.resume() }
            return .success
        }

        commands.pauseCommand.isEnabled = true
        commands.pauseCommand.addTarget { [weak self] _ in
            guard self?.currentTrack != nil else { return .noSuchContent }
            DispatchQueue.main.async { self?.pause() }
            return .success
        }

        commands.togglePlayPauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard self?.currentTrack != nil else { return .noSuchContent }
            DispatchQueue.main.async { self?.togglePlayPause() }
            return .success
        }

        commands.nextTrackCommand.addTarget { [weak self] _ in
            guard self?.currentTrack != nil else { return .noSuchContent }
            DispatchQueue.main.async { self?.next() }
            return .success
        }

        commands.previousTrackCommand.addTarget { [weak self] _ in
            guard self?.currentTrack != nil else { return .noSuchContent }
            DispatchQueue.main.async { self?.previous() }
            return .success
        }

        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent,
                  self?.currentTrack != nil else { return .commandFailed }
            DispatchQueue.main.async { self?.seek(to: event.positionTime) }
            return .success
        }

        commands.changeShuffleModeCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangeShuffleModeCommandEvent else { return .commandFailed }
            let enabled = event.shuffleType != .off
            DispatchQueue.main.async { self?.setShuffleEnabled(enabled) }
            return .success
        }

        commands.changeRepeatModeCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangeRepeatModeCommandEvent else { return .commandFailed }
            let mode: AudioRepeatMode
            switch event.repeatType {
            case .one: mode = .one
            case .all: mode = .all
            default: mode = .off
            }
            DispatchQueue.main.async { self?.setRepeatMode(mode) }
            return .success
        }

        commands.likeCommand.isEnabled = true
        commands.likeCommand.localizedTitle = "Добавить музыку"
        commands.likeCommand.localizedShortTitle = "В музыку"
        commands.likeCommand.addTarget { [weak self] event in
            guard let self = self,
                  let track = self.currentTrack,
                  let feedback = event as? MPFeedbackCommandEvent,
                  AudioLibraryMembership.shared.canMutate(track) else {
                return .noSuchContent
            }
            let shouldAdd = !feedback.isNegative
            DispatchQueue.main.async {
                AudioLibraryMembership.shared.setAdded(shouldAdd, for: track)
            }
            return .success
        }
    }

    private func syncRemoteCommandState() {
        let commands = MPRemoteCommandCenter.shared()
        let hasTrack = currentTrack != nil
        let hasQueue = queue.count > 1

        commands.playCommand.isEnabled = hasTrack && !isPlaying
        commands.pauseCommand.isEnabled = hasTrack && isPlaying
        commands.togglePlayPauseCommand.isEnabled = hasTrack
        commands.nextTrackCommand.isEnabled = hasQueue
        commands.previousTrackCommand.isEnabled = hasQueue
        commands.changePlaybackPositionCommand.isEnabled = hasTrack
        commands.changeShuffleModeCommand.isEnabled = hasQueue
        commands.changeRepeatModeCommand.isEnabled = hasTrack
        commands.changeShuffleModeCommand.currentShuffleType = shuffleEnabled ? .items : .off

        if let track = currentTrack {
            commands.likeCommand.isEnabled = AudioLibraryMembership.shared.canMutate(track)
            commands.likeCommand.isActive = AudioLibraryMembership.shared.isAdded(track)
        } else {
            commands.likeCommand.isEnabled = false
            commands.likeCommand.isActive = false
        }

        switch repeatMode {
        case .off: commands.changeRepeatModeCommand.currentRepeatType = .off
        case .all: commands.changeRepeatModeCommand.currentRepeatType = .all
        case .one: commands.changeRepeatModeCommand.currentRepeatType = .one
        }
    }

    private func updateNowPlayingInfo(loadArtwork: Bool = false) {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: max(0, duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, currentTime),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyPlaybackQueueCount: queue.count,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: currentIndex ?? 0
        ]

        if loadedArtworkKey == trackKey(track), let artwork = loadedArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        } else {
            info[MPMediaItemPropertyArtwork] = placeholderArtwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        if loadArtwork {
            loadArtworkIfNeeded(for: track)
        }
    }

    private func loadArtworkIfNeeded(for track: AudioTrack) {
        artworkTask?.cancel()
        artworkTask = nil

        let key = trackKey(track)

        if let artworkURL = track.artworkURL,
           let sanitized = AudioService.sanitizeArtworkURL(artworkURL),
           let url = URL(string: sanitized) {
            downloadArtworkImage(from: url, for: key)
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            let itunesURLString = await ITunesArtworkService.shared.fetchTrackArtworkURL(
                artist: track.artist,
                title: track.title
            )
            guard let itunesURLString = itunesURLString,
                  let sanitized = AudioService.sanitizeArtworkURL(itunesURLString),
                  let url = URL(string: sanitized) else {
                await MainActor.run {
                    guard let current = self.currentTrack, self.trackKey(current) == key else { return }
                    self.loadedArtworkKey = nil
                    self.loadedArtwork = nil
                    self.updateNowPlayingInfo()
                }
                return
            }

            await MainActor.run {
                guard let current = self.currentTrack, self.trackKey(current) == key else { return }
                self.downloadArtworkImage(from: url, for: key)
            }
        }
    }

    private func downloadArtworkImage(from url: URL, for key: String) {
        artworkTask?.cancel()
        artworkTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data) else { return }

            DispatchQueue.main.async {
                guard let current = self.currentTrack,
                      self.trackKey(current) == key else { return }
                self.loadedArtworkKey = key
                self.loadedArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.updateNowPlayingInfo()
            }
        }
        artworkTask?.resume()
    }

    private func trackKey(_ track: AudioTrack) -> String {
        if let ownerID = track.ownerID, let vkID = track.vkID {
            return "\(ownerID)_\(vkID)"
        }
        return track.id.uuidString
    }

    private func isSameTrack(_ lhs: AudioTrack, _ rhs: AudioTrack?) -> Bool {
        guard let rhs = rhs else { return false }
        if let lhsOwner = lhs.ownerID, let rhsOwner = rhs.ownerID,
           let lhsID = lhs.vkID, let rhsID = rhs.vkID {
            return lhsOwner == rhsOwner && lhsID == rhsID
        }
        return lhs.id == rhs.id
    }

    @objc private func audioSessionInterrupted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let info = notification.userInfo,
                  let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

            switch type {
            case .began:
                self.player.pause()
                self.isPlaying = false
                self.updateNowPlayingInfo()
                self.syncRemoteCommandState()
            case .ended:
                let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                if options.contains(.shouldResume), self.currentTrack != nil {
                    self.resume()
                }
            @unknown default:
                break
            }
        }
    }

    @objc private func audioLibraryStateDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.syncRemoteCommandState()
        }
    }

    @objc private func accountDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.stop()
        }
    }

    @objc private func playerItemDidFinish(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem,
              item === player.currentItem else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isCrossfading {
                self.finalizeCrossfade()
            } else {
                self.next(userInitiated: false)
            }
        }
    }
}
