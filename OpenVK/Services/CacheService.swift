//
//  CacheService.swift
//  OpenVK for iOS
//
//  Сервис кэширования API-ответов.
//

import Foundation
import UIKit

final class CacheService {

    static let shared = CacheService()

    private let ttl: TimeInterval = 5 * 60 // 5 минут

    private let cacheDirectoryName = "openvk_api_cache"

    private lazy var cacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent(cacheDirectoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        URLCache.shared.memoryCapacity = 50 * 1024 * 1024
        URLCache.shared.diskCapacity = 200 * 1024 * 1024
    }

    // MARK: - Public API

    func cachedData(for key: String) -> Data? {
        let fileURL = cacheFile(for: key)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let modified = attrs[.modificationDate] as? Date {
            if Date().timeIntervalSince(modified) > ttl {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
        }
        return try? Data(contentsOf: fileURL)
    }

    func cache(data: Data, for key: String) {
        let fileURL = cacheFile(for: key)
        try? data.write(to: fileURL, options: .atomic)
    }

    func invalidate(key: String) {
        let fileURL = cacheFile(for: key)
        try? FileManager.default.removeItem(at: fileURL)
    }

    func clearAll() {
        if let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
        URLCache.shared.removeAllCachedResponses()
    }

    func totalCacheSizeBytes() -> Int64 {
        let diskBytes = directorySize(url: cacheDirectory)
        let urlCacheBytes = Int64(URLCache.shared.currentDiskUsage)
        return diskBytes + urlCacheBytes
    }

    func totalCacheSizeString() -> String {
        let bytes = totalCacheSizeBytes()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func cacheFile(for key: String) -> URL {
        let scopedKey = "\(AuthService.shared.currentUser?.uid ?? 0)_\(key)"
        let safeKey = scopedKey
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
            .replacingOccurrences(of: "=", with: "_")
        let fileName = safeKey.count > 200 ? String(safeKey.prefix(200)) : safeKey
        return cacheDirectory.appendingPathComponent("\(fileName).json")
    }

    private func directorySize(url: URL) -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return 0 }
        return files.compactMap {
            (try? $0.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        }.reduce(0) { $0 + Int64($1) }
    }
}
