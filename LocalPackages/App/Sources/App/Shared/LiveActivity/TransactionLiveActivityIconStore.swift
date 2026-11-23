import Combine
import CryptoKit
import Foundation
import KeeperCore
import TKLogging
import TKUIKit
import UIKit

enum TransactionLiveActivityIconSource: Hashable {
    case ton
    case usdt
    case trx
    case url(URL)
    /// A multichain asset whose logo the asset catalog knows.
    case asset(id: String)
}

/// Saves token logos where the widget extension reads them. A logo saved after the activity was shown
/// asks for a refresh, which puts its file name into the state.
@MainActor
final class TransactionLiveActivityIconStore {
    /// 44 pt at 3x: the largest the activity draws a logo.
    private static let side: CGFloat = 132
    private static let lifetime: TimeInterval = 2 * 24 * 60 * 60
    private static let retryDelay: TimeInterval = 5 * 60

    private let directory: URL?
    private let assetDetailsService: TradingAssetDetailsService
    private let loadImage: (URL) async -> UIImage?
    private var loads: Set<TransactionLiveActivityIconSource> = []
    private var failedAt: [TransactionLiveActivityIconSource: Date] = [:]
    var onSave: (() -> Void)?

    init(
        directory: URL? = TransactionLiveActivityIcons.directory,
        assetDetailsService: TradingAssetDetailsService,
        loadImage: @escaping (URL) async -> UIImage? = TransactionLiveActivityIconStore.loadImage
    ) {
        self.directory = directory
        self.assetDetailsService = assetDetailsService
        self.loadImage = loadImage
    }

    /// The saved logo's file name, or `nil` while it loads or after it failed.
    func fileName(for source: TransactionLiveActivityIconSource?) -> String? {
        guard let source, let directory else { return nil }
        let name = Self.fileName(for: source)
        let url = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) {
            // A logo still in use outlives the cleanup.
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
            return name
        }
        if let image = Self.bundledImage(for: source) {
            return save(image, as: name) ? name : nil
        }
        load(source, as: name)
        return nil
    }

    private func load(_ source: TransactionLiveActivityIconSource, as name: String) {
        guard !loads.contains(source),
              failedAt[source].map({ Date().timeIntervalSince($0) > Self.retryDelay }) ?? true
        else { return }
        loads.insert(source)
        Task { [weak self] in
            guard let self else { return }
            let url = await remoteURL(for: source)
            let image = if let url { await loadImage(url) } else { UIImage?.none }
            loads.remove(source)
            guard let image, save(image, as: name) else {
                failedAt[source] = Date()
                return
            }
            failedAt[source] = nil
            onSave?()
        }
    }

    private func remoteURL(for source: TransactionLiveActivityIconSource) async -> URL? {
        switch source {
        case let .url(url):
            return url
        case let .asset(id):
            if let details = await assetDetailsService.assetDetails(for: id) {
                return details.assetInfo.imageURL
            }
            return try? await assetDetailsService.loadAssetDetails(id: id).assetInfo.imageURL
        case .ton, .usdt, .trx:
            return nil
        }
    }

    private func save(_ image: UIImage, as name: String) -> Bool {
        guard let directory else { return false }
        let side = Self.side
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).pngData { _ in
            let scale = max(side / max(image.size.width, 1), side / max(image.size.height, 1))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Readable on the Lock Screen of a device unlocked once since boot.
            try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Log.w("Live Activity: saving a token logo failed", error: error)
            return false
        }
        removeExpired(in: directory, keeping: name)
        return true
    }

    private func removeExpired(in directory: URL, keeping name: String) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        let expiry = Date().addingTimeInterval(-Self.lifetime)
        for file in files where file.lastPathComponent != name {
            let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if let modified, modified < expiry {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    static func fileName(for source: TransactionLiveActivityIconSource) -> String {
        switch source {
        case .ton: "ton.png"
        case .usdt: "usdt.png"
        case .trx: "trx.png"
        case let .url(url): "url-\(digest(url.absoluteString)).png"
        case let .asset(id): "asset-\(digest(id.lowercased())).png"
        }
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static func bundledImage(for source: TransactionLiveActivityIconSource) -> UIImage? {
        switch source {
        case .ton: .TKUIKit.Icons.Size44.currencyTon
        case .usdt: .TKUIKit.Icons.Size44.currencyUsdt
        case .trx: .TKUIKit.Icons.Size44.trxChain
        case .url, .asset: nil
        }
    }

    nonisolated static func loadImage(_ url: URL) async -> UIImage? {
        let prefetcher = ImagePrefetcherService()
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = prefetcher.loadImage(url: url) { image in
                continuation.resume(returning: image)
                _ = cancellable
            }
        }
    }
}
