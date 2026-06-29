import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import os

#if canImport(UIKit)
private final class CachedRemoteImageStore {
    static let shared = CachedRemoteImageStore()

    private let cache = NSCache<NSURL, UIImage>()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Anixart", category: "image-cache")
    private let lock = NSLock()
    private var loggedKeys = Set<String>()

    private init() {
        cache.countLimit = 350
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> UIImage? {
        let key = url as NSURL
        let image = cache.object(forKey: key)
        logOnce(message: image == nil ? "Image cache miss" : "Image cache hit", url: url)
        return image
    }

    func image(for url: URL) async -> UIImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            logOnce(message: "Image cache hit", url: url)
            return cached
        }

        logOnce(message: "Image cache miss", url: url)

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return nil
            }
            guard let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: key, cost: data.count)
            return image
        } catch {
            return nil
        }
    }

    private func logOnce(message: String, url: URL) {
        let key = "\(message):\(url.absoluteString)"
        lock.lock()
        let shouldLog = loggedKeys.insert(key).inserted
        lock.unlock()
        guard shouldLog else { return }
        logger.debug("\(message, privacy: .public) host=\(url.host ?? "-", privacy: .public)")
    }
}

struct CachedRemoteImageView<Placeholder: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(
        urlString: String?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        let url = urlString.flatMap(URL.init(string:))
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
        _image = State(initialValue: url.flatMap { CachedRemoteImageStore.shared.cachedImage(for: $0) })
    }

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
        _image = State(initialValue: url.flatMap { CachedRemoteImageStore.shared.cachedImage(for: $0) })
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
            await loadImage()
        }
        .onChange(of: url) { _, newURL in
            image = newURL.flatMap { CachedRemoteImageStore.shared.cachedImage(for: $0) }
        }
    }

    private func loadImage() async {
        guard image == nil, let url else { return }
        let loadedImage = await CachedRemoteImageStore.shared.image(for: url)
        guard !Task.isCancelled else { return }
        image = loadedImage
    }
}
#endif
