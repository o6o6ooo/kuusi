import Combine
import SwiftUI
import UIKit

struct CachedRemoteImageView<Content: View, Placeholder: View>: View {
    @StateObject private var loader: Loader
    private let url: URL?

    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
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
        .task(id: url) {
            await loader.load(url: url)
        }
    }
}

extension CachedRemoteImageView where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?) {
        self.init(url: url) { $0 } placeholder: { ProgressView() }
    }
}

@MainActor
private final class Loader: ObservableObject {
    @Published private(set) var image: UIImage?
    private var loadedURL: URL?

    func load(url: URL?) async {
        guard loadedURL != url else { return }
        loadedURL = url
        image = nil

        guard let url else { return }

        if let cached = await FeedImageCache.shared.image(for: url) {
            image = cached
            return
        }

        do {
            let loaded = try await FeedImageCache.shared.loadImage(from: url)
            image = loaded
        } catch {
            return
        }
    }
}

private actor FeedImageCache {
    static let shared = FeedImageCache()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private let urlCache: URLCache

    private init() {
        memoryCache.countLimit = 300
        memoryCache.totalCostLimit = 80 * 1024 * 1024

        urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            diskPath: "feed-image-cache"
        )

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = urlCache
        session = URLSession(configuration: configuration)
    }

    func image(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    func loadImage(from url: URL) async throws -> UIImage {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
        if let cachedResponse = urlCache.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            store(image, for: url, data: cachedResponse.data)
            return image
        }

        let (data, response) = try await session.data(for: request)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
            let cachedResponse = CachedURLResponse(response: response, data: data)
            urlCache.storeCachedResponse(cachedResponse, for: request)
        }

        store(image, for: url, data: data)
        return image
    }

    private func store(_ image: UIImage, for url: URL, data: Data) {
        memoryCache.setObject(image, forKey: url as NSURL, cost: data.count)
    }
}
