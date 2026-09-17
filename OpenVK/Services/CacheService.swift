//
//  CacheService.swift
//  OpenVK for iOS
//  Сервис кэширования.
//

import CryptoKit
import Foundation
import Network
import SwiftUI
import UIKit

final class ImageCache {
    static let shared = ImageCache()

    private struct LoadKey: Hashable {
        let url: URL
        let forceRefresh: Bool
    }

    private final class Entry: NSObject {
        let image: UIImage
        let createdAt: Date

        init(image: UIImage, createdAt: Date) {
            self.image = image
            self.createdAt = createdAt
        }
    }

    private let cache = NSCache<NSURL, Entry>()
    private let queue = DispatchQueue(label: "org.openvk.image-cache")
    private let prefetchQueue = DispatchQueue(label: "org.openvk.image-prefetch", qos: .utility, attributes: .concurrent)
    private var pendingLoads: [LoadKey: [(UIImage?) -> Void]] = [:]
    private let lifetime: TimeInterval = 10 * 60
    private let diskLifetime: TimeInterval = 24 * 60 * 60
    private let diskLimitBytes: Int64 = 200 * 1024 * 1024
    private let fileManager = FileManager.default
    private lazy var diskDirectory: URL = {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let directory = caches.appendingPathComponent("openvk_image_cache_v1", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 100 * 1024 * 1024
    }

    func image(for url: URL, maximumAge: TimeInterval? = nil) -> UIImage? {
        let allowedAge = maximumAge ?? lifetime
        if let entry = cache.object(forKey: url as NSURL) {
            guard Date().timeIntervalSince(entry.createdAt) <= allowedAge else {
                cache.removeObject(forKey: url as NSURL)
                return nil
            }
            return entry.image
        }

        guard let diskEntry = readDiskEntry(for: url),
              Date().timeIntervalSince(diskEntry.createdAt) <= allowedAge else {
            removeDiskEntry(for: url)
            return nil
        }

        cache.setObject(diskEntry.entry, forKey: url as NSURL, cost: diskEntry.dataSize)
        return diskEntry.entry.image
    }

    func load(
        _ url: URL,
        maximumAge: TimeInterval? = nil,
        forceRefresh: Bool = false,
        completion: @escaping (UIImage?) -> Void
    ) {
        if !forceRefresh, let image = image(for: url, maximumAge: maximumAge) {
            DispatchQueue.main.async { completion(image) }
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }
            let loadKey = LoadKey(url: url, forceRefresh: forceRefresh)
            if self.pendingLoads[loadKey] != nil {
                self.pendingLoads[loadKey, default: []].append(completion)
                return
            }

            self.pendingLoads[loadKey] = [completion]
            let requestURL: URL
            if forceRefresh,
               var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var queryItems = components.queryItems ?? []
                queryItems.append(URLQueryItem(name: "ovk_cache_bust", value: UUID().uuidString))
                components.queryItems = queryItems
                requestURL = components.url ?? url
            } else {
                requestURL = url
            }

            var request = URLRequest(url: requestURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            if forceRefresh {
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                request.setValue("no-cache", forHTTPHeaderField: "Pragma")
            }

            let session = forceRefresh
                ? URLSession(configuration: .ephemeral)
                : URLSession.shared

            session.dataTask(with: request) { [weak self] data, _, _ in
                guard let self = self else { return }
                let image = data.flatMap(UIImage.init(data:))
                if let image, let data {
                    let entry = Entry(image: image, createdAt: Date())
                    self.cache.setObject(entry, forKey: url as NSURL, cost: data.count)
                    self.writeDiskEntry(data: data, createdAt: entry.createdAt, for: url)
                }

                let completions = self.queue.sync {
                    self.pendingLoads.removeValue(forKey: loadKey) ?? []
                }
                DispatchQueue.main.async {
                    completions.forEach { $0(image) }
                }
            }.resume()
        }
    }

    func prefetch(_ urls: [URL]) {
        let semaphore = DispatchSemaphore(value: 4)
        for url in Set(urls) where image(for: url) == nil {
            prefetchQueue.async { [weak self] in
                guard let self = self else { return }
                semaphore.wait()
                self.load(url) { _ in
                    semaphore.signal()
                }
            }
        }
    }

    func clear() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: diskDirectory)
    }

    func diskCacheSizeBytes() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        return files.compactMap {
            (try? $0.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        }.reduce(0) { $0 + Int64($1) }
    }

    private struct DiskEntry {
        let entry: Entry
        let dataSize: Int
        let createdAt: Date
    }

    private func diskURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent(name).appendingPathExtension("image")
    }

    private func readDiskEntry(for url: URL) -> DiskEntry? {
        let fileURL = diskURL(for: url)
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data),
              let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        else { return nil }

        return DiskEntry(
            entry: Entry(image: image, createdAt: modified),
            dataSize: data.count,
            createdAt: modified
        )
    }

    private func writeDiskEntry(data: Data, createdAt: Date, for url: URL) {
        let fileURL = diskURL(for: url)
        try? fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
        try? fileManager.setAttributes([.modificationDate: createdAt], ofItemAtPath: fileURL.path)
        trimDiskCacheIfNeeded()
    }

    private func removeDiskEntry(for url: URL) {
        try? fileManager.removeItem(at: diskURL(for: url))
    }

    private func trimDiskCacheIfNeeded() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        var entries = files.compactMap { file -> (url: URL, size: Int64, date: Date)? in
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize,
                  let date = values.contentModificationDate else { return nil }
            return (file, Int64(size), date)
        }
        let expirationDate = Date().addingTimeInterval(-diskLifetime)
        entries = entries.filter { entry in
            guard entry.date >= expirationDate else {
                try? fileManager.removeItem(at: entry.url)
                return false
            }
            return true
        }
        var total = entries.reduce(Int64(0)) { $0 + $1.size }
        for entry in entries.sorted(by: { $0.date < $1.date }) where total > diskLimitBytes {
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }
}

struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL
    let contentMode: ContentMode
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var requestedURL: URL?

    init(
        url: URL,
        contentMode: ContentMode = .fit,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            requestedURL = url
            image = ImageCache.shared.image(for: url)
            guard image == nil else { return }
            ImageCache.shared.load(url) { image in
                guard requestedURL == url else { return }
                self.image = image
            }
        }
    }
}

final class ConnectionStatusService: ObservableObject {
    enum Issue: Equatable {
        case noInternet
        case serverUnavailable

        var title: String {
            switch self {
            case .noInternet: return "Нет подключения"
            case .serverUnavailable: return "Сервер недоступен"
            }
        }

        var details: String {
            switch self {
            case .noInternet:
                return "Устройство не подключено к интернету. Проверьте Wi‑Fi или мобильную сеть и повторите попытку."
            case .serverUnavailable:
                return "Интернет работает, но текущий OpenVK-инстанс не отвечает. Возможно, на сервере проводятся работы или он временно недоступен."
            }
        }
    }

    static let shared = ConnectionStatusService()

    @Published private(set) var issue: Issue?
    @Published private(set) var isChecking = false

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "org.openvk.connection-status")
    private var isMonitoring = false
    private var probeWorkItem: DispatchWorkItem?

    private init() {}

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            if path.status != .satisfied {
                self.update(issue: .noInternet)
                self.cancelScheduledProbe()
            } else {
                self.refresh()
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    func refresh() {
        guard pathMonitor.currentPath.status == .satisfied else {
            update(issue: .noInternet)
            return
        }

        DispatchQueue.main.async { self.isChecking = true }
        var request = URLRequest(url: AppConfig.apiBaseURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            let isReachable = error == nil && response is HTTPURLResponse
            self.update(issue: isReachable ? nil : .serverUnavailable)
            self.scheduleNextProbe()
        }.resume()
    }

    func recordServerSuccess() {
        update(issue: nil)
    }

    func recordServerFailure() {
        guard pathMonitor.currentPath.status == .satisfied else {
            update(issue: .noInternet)
            return
        }
        update(issue: .serverUnavailable)
    }

    private func update(issue: Issue?) {
        DispatchQueue.main.async {
            self.isChecking = false
            self.issue = issue
        }
    }

    private func scheduleNextProbe() {
        cancelScheduledProbe()
        let workItem = DispatchWorkItem { [weak self] in self?.refresh() }
        probeWorkItem = workItem
        monitorQueue.asyncAfter(deadline: .now() + 30, execute: workItem)
    }

    private func cancelScheduledProbe() {
        probeWorkItem?.cancel()
        probeWorkItem = nil
    }
}

final class CacheService {
    static let shared = CacheService()

    private struct Record: Codable {
        let schemaVersion: Int
        let createdAt: Date
        let payload: Data
    }

    private let schemaVersion = 2
    private let fallbackLifetime: TimeInterval = 24 * 60 * 60
    private let cacheDirectoryName = "openvk_response_cache_v2"
    private let legacyCacheDirectoryName = "openvk_api_cache"
    private let fileManager = FileManager.default
    private let lock = NSLock()

    private lazy var cacheDirectory: URL = {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let directory = caches.appendingPathComponent(cacheDirectoryName, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let legacyDirectory = caches.appendingPathComponent(legacyCacheDirectoryName, isDirectory: true)
        try? fileManager.removeItem(at: legacyDirectory)

        URLCache.shared.memoryCapacity = 20 * 1024 * 1024
        URLCache.shared.diskCapacity = 50 * 1024 * 1024
    }

    func cachedData(for key: String, maximumAge: TimeInterval? = nil) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let fileURL = cacheFile(for: key)
        guard let data = try? Data(contentsOf: fileURL),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.schemaVersion == schemaVersion else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        let maxAge = maximumAge ?? fallbackLifetime
        guard Date().timeIntervalSince(record.createdAt) <= maxAge else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        return record.payload
    }

    func cache(data: Data, for key: String) {
        let record = Record(schemaVersion: schemaVersion, createdAt: Date(), payload: data)
        guard let encoded = try? JSONEncoder().encode(record) else { return }

        lock.lock()
        defer { lock.unlock() }
        try? encoded.write(to: cacheFile(for: key), options: .atomic)
    }

    func invalidate(key: String) {
        lock.lock()
        defer { lock.unlock() }
        try? fileManager.removeItem(at: cacheFile(for: key))
    }

    func clearAll() {
        lock.lock()
        let directory = cacheDirectory
        if let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            files.forEach { try? fileManager.removeItem(at: $0) }
        }
        lock.unlock()

        ImageCache.shared.clear()
        URLCache.shared.removeAllCachedResponses()
    }

    func totalCacheSizeBytes() -> Int64 {
        lock.lock()
        cleanupExpiredRecords()
        let responseCacheBytes = directorySize(url: cacheDirectory)
        lock.unlock()
        return responseCacheBytes + ImageCache.shared.diskCacheSizeBytes() + Int64(URLCache.shared.currentDiskUsage)
    }

    func totalCacheSizeString() -> String {
        ByteCountFormatter.string(fromByteCount: totalCacheSizeBytes(), countStyle: .file)
    }

    private func cacheFile(for key: String) -> URL {
        let scope = "\(AppConfig.currentHost)|\(AuthService.shared.currentUser?.uid ?? 0)|\(key)"
        let digest = SHA256.hash(data: Data(scope.utf8))
        let fileName = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(fileName).appendingPathExtension("cache")
    }

    private func directorySize(url: URL) -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        return files.compactMap {
            (try? $0.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        }.reduce(0) { $0 + Int64($1) }
    }

    private func cleanupExpiredRecords() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }

        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let record = try? JSONDecoder().decode(Record.self, from: data),
                  record.schemaVersion == schemaVersion,
                  Date().timeIntervalSince(record.createdAt) <= fallbackLifetime else {
                try? fileManager.removeItem(at: file)
                continue
            }
        }
    }
}
