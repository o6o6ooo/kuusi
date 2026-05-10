import Combine
import CryptoKit
import FirebaseStorage
import Foundation
import SwiftUI
import UIKit

nonisolated enum FeedImageSource: Equatable {
    case storagePath(String)

    fileprivate var cacheKey: String {
        switch self {
        case let .storagePath(path):
            return "storage:\(path)"
        }
    }
}

struct CachedRemoteImageView<Content: View, Placeholder: View>: View {
    @StateObject private var loader: Loader
    private let source: FeedImageSource?

    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    init(
        source: FeedImageSource?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.source = source
        _loader = StateObject(wrappedValue: Loader())
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: source) {
            await loader.load(source: source)
        }
    }
}

extension CachedRemoteImageView where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(source: FeedImageSource?) {
        self.init(source: source) { $0 } placeholder: { ProgressView() }
    }
}

enum FeedImageCacheMaintenance {
    static func clearDiskCache() async {
        await FeedImageCache.shared.clearDiskCache()
    }
}

@MainActor
private final class Loader: ObservableObject {
    @Published private(set) var image: UIImage?
    private var loadedSource: FeedImageSource?
    private var loadTask: Task<Void, Never>?

    func load(source: FeedImageSource?) async {
        guard loadedSource != source else { return }
        loadTask?.cancel()
        loadedSource = source
        image = nil

        guard let source else { return }

        if let cached = await FeedImageCache.shared.image(for: source) {
            image = cached
            return
        }

        loadTask = Task { [weak self] in
            do {
                let loaded = try await FeedImageCache.shared.loadImage(from: source)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.image = loaded
                }
            } catch {
                return
            }
        }

        await loadTask?.value
    }
}

private actor FeedImageCache {
    static let shared = FeedImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let storage = Storage.storage()
    private let fileManager = FileManager.default
    private let cacheDirectoryURL: URL
    private let maxStorageReadBytes: Int64 = 12 * 1024 * 1024
    private let staleImageCacheInterval: TimeInterval = 60 * 24 * 60 * 60
    private let cleanupInterval: TimeInterval = 24 * 60 * 60
    private let cleanupDefaultsKey = "feed_storage_image_cache_last_cleanup_v1"

    private init() {
        memoryCache.countLimit = 300
        memoryCache.totalCostLimit = 80 * 1024 * 1024

        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        cacheDirectoryURL = cachesDirectory.appendingPathComponent("feed-storage-image-cache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        Self.cleanUpDiskCacheIfNeeded(
            fileManager: fileManager,
            cacheDirectoryURL: cacheDirectoryURL,
            staleImageCacheInterval: staleImageCacheInterval,
            cleanupInterval: cleanupInterval,
            cleanupDefaultsKey: cleanupDefaultsKey
        )
    }

    func image(for source: FeedImageSource) -> UIImage? {
        memoryCache.object(forKey: source.cacheKey as NSString)
    }

    func clearDiskCache() {
        memoryCache.removeAllObjects()
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in files where fileURL.pathExtension == "imgcache" {
            try? fileManager.removeItem(at: fileURL)
        }
        UserDefaults.standard.removeObject(forKey: cleanupDefaultsKey)
    }

    func loadImage(from source: FeedImageSource) async throws -> UIImage {
        let cacheKey = source.cacheKey

        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        if let diskImage = loadDiskImage(for: cacheKey) {
            memoryCache.setObject(diskImage.image, forKey: cacheKey as NSString, cost: diskImage.data.count)
            return diskImage.image
        }

        let data = try await loadImageData(from: source)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        store(image, for: cacheKey, data: data)
        return image
    }

    private func loadImageData(from source: FeedImageSource) async throws -> Data {
        switch source {
        case let .storagePath(path):
            let reference = storage.reference(withPath: path)
            return try await withCheckedThrowingContinuation { continuation in
                reference.getData(maxSize: maxStorageReadBytes) { data, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let data else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }

                    continuation.resume(returning: data)
                }
            }
        }
    }

    private func loadDiskImage(for cacheKey: String) -> (image: UIImage, data: Data)? {
        let fileURL = fileURL(for: cacheKey)
        guard
            let data = try? Data(contentsOf: fileURL),
            let image = UIImage(data: data)
        else {
            return nil
        }

        updateLastAccessDate(for: fileURL)
        return (image, data)
    }

    private func store(_ image: UIImage, for cacheKey: String, data: Data) {
        memoryCache.setObject(image, forKey: cacheKey as NSString, cost: data.count)

        let fileURL = fileURL(for: cacheKey)
        do {
            try data.write(to: fileURL, options: .atomic)
            updateLastAccessDate(for: fileURL)
        } catch {
            return
        }
    }

    private static func cleanUpDiskCacheIfNeeded(
        fileManager: FileManager,
        cacheDirectoryURL: URL,
        staleImageCacheInterval: TimeInterval,
        cleanupInterval: TimeInterval,
        cleanupDefaultsKey: String,
        now: Date = Date()
    ) {
        let defaults = UserDefaults.standard
        if let lastCleanup = defaults.object(forKey: cleanupDefaultsKey) as? Date,
           now.timeIntervalSince(lastCleanup) < cleanupInterval {
            return
        }

        cleanUpStaleDiskImages(
            fileManager: fileManager,
            cacheDirectoryURL: cacheDirectoryURL,
            staleImageCacheInterval: staleImageCacheInterval,
            now: now
        )
        defaults.set(now, forKey: cleanupDefaultsKey)
    }

    private static func cleanUpStaleDiskImages(
        fileManager: FileManager,
        cacheDirectoryURL: URL,
        staleImageCacheInterval: TimeInterval,
        now: Date
    ) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectoryURL,
            includingPropertiesForKeys: [.contentAccessDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let cutoff = now.addingTimeInterval(-staleImageCacheInterval)
        for fileURL in files where fileURL.pathExtension == "imgcache" {
            guard let lastUsedAt = lastUsedDate(for: fileURL), lastUsedAt < cutoff else {
                continue
            }
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private static func lastUsedDate(for fileURL: URL) -> Date? {
        guard let values = try? fileURL.resourceValues(forKeys: [.contentAccessDateKey, .contentModificationDateKey]) else {
            return nil
        }
        return values.contentAccessDate ?? values.contentModificationDate
    }

    private func updateLastAccessDate(for fileURL: URL, now: Date = Date()) {
        var mutableURL = fileURL
        var values = URLResourceValues()
        values.contentAccessDate = now
        values.contentModificationDate = now
        try? mutableURL.setResourceValues(values)
    }

    private func fileURL(for cacheKey: String) -> URL {
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
        let fileName = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectoryURL.appendingPathComponent(fileName).appendingPathExtension("imgcache")
    }
}
