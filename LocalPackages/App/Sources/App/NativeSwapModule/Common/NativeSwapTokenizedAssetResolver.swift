import Foundation
import KeeperCore
import TKLogging
import TonSwift

enum NativeSwapAssetClassification: Equatable {
    case crypto
    case stock
    case etf

    var isTokenized: Bool {
        switch self {
        case .stock, .etf:
            return true
        case .crypto:
            return false
        }
    }
}

final class NativeSwapTokenizedAssetResolver {
    private let assetDetailsService: TradingAssetDetailsService
    private let network: Network
    private let cache = NativeSwapTokenizedAssetCache()

    init(
        assetDetailsService: TradingAssetDetailsService,
        network: Network
    ) {
        self.assetDetailsService = assetDetailsService
        self.network = network
    }

    func cachedClassification(for token: KeeperCore.Token) -> NativeSwapAssetClassification? {
        switch token {
        case .ton(.ton), .tron:
            return .crypto
        case let .ton(.jetton(jettonItem)):
            return cachedClassification(for: jettonItem.jettonInfo.address)
        }
    }

    func cachedClassification(for address: Address) -> NativeSwapAssetClassification? {
        if address == JettonMasterAddress.tonUSDT {
            return .crypto
        }

        if address == JettonMasterAddress.SPYx {
            return .etf
        }

        let key = cacheKey(for: address)
        return cache.resolvedClassification(for: key)
    }

    func setClassification(_ category: TradingAssetCategory, for token: KeeperCore.Token) {
        setClassification(NativeSwapAssetClassification(category: category), for: token)
    }

    func setClassification(_ classification: NativeSwapAssetClassification, for token: KeeperCore.Token) {
        switch token {
        case .ton(.ton), .tron:
            return
        case let .ton(.jetton(jettonItem)):
            setClassification(classification, for: jettonItem.jettonInfo.address)
        }
    }

    func setClassification(_ classification: NativeSwapAssetClassification, for address: Address) {
        let key = cacheKey(for: address)
        cache.setResolvedClassification(classification, for: key)
    }

    @discardableResult
    func resolveClassification(for token: KeeperCore.Token) async -> NativeSwapAssetClassification {
        switch token {
        case .ton(.ton), .tron:
            return .crypto
        case let .ton(.jetton(jettonItem)):
            return await resolveClassification(for: jettonItem.jettonInfo.address)
        }
    }

    @discardableResult
    func resolveClassification(for address: Address) async -> NativeSwapAssetClassification {
        if let classification = cachedClassification(for: address) {
            return classification
        }

        let key = cacheKey(for: address)
        if let task = cache.resolvingTask(for: key) {
            return await task.value
        }

        let task = Task<NativeSwapAssetClassification, Never> { [assetDetailsService, network] in
            await Self.loadClassification(
                for: address,
                network: network,
                assetDetailsService: assetDetailsService
            )
        }
        cache.setResolvingTask(task, for: key)

        let classification = await task.value

        cache.setResolvedClassification(classification, for: key)

        return classification
    }
}

private final class NativeSwapTokenizedAssetCache {
    private enum CacheValue {
        case resolved(NativeSwapAssetClassification)
        case resolving(Task<NativeSwapAssetClassification, Never>)
    }

    private let lock = NSLock()
    private var cache = [String: CacheValue]()

    func resolvedClassification(for key: String) -> NativeSwapAssetClassification? {
        lock.lock()
        defer { lock.unlock() }

        guard case let .resolved(classification) = cache[key] else {
            return nil
        }
        return classification
    }

    func resolvingTask(for key: String) -> Task<NativeSwapAssetClassification, Never>? {
        lock.lock()
        defer { lock.unlock() }

        guard case let .resolving(task) = cache[key] else {
            return nil
        }
        return task
    }

    func setResolvingTask(_ task: Task<NativeSwapAssetClassification, Never>, for key: String) {
        lock.lock()
        cache[key] = .resolving(task)
        lock.unlock()
    }

    func setResolvedClassification(_ classification: NativeSwapAssetClassification, for key: String) {
        lock.lock()
        cache[key] = .resolved(classification)
        lock.unlock()
    }
}

private extension NativeSwapTokenizedAssetResolver {
    static func loadClassification(
        for address: Address,
        network: Network,
        assetDetailsService: TradingAssetDetailsService
    ) async -> NativeSwapAssetClassification {
        let address = address.toRaw()

        let assetId = "ton/\(network.tradeAssetNetworkIdentifier)/jetton/\(address)"

        if let cachedDetails = await assetDetailsService.assetDetails(for: assetId) {
            return NativeSwapAssetClassification(
                category: cachedDetails.assetInfo.category
            )
        }

        let details: TradingAssetDetails
        do {
            details = try await assetDetailsService.loadAssetDetails(id: assetId)
        } catch {
            Log.w("unable to determine asset type, loadAssetDetails failed due to error: \(error)")
            return .crypto
        }

        return NativeSwapAssetClassification(
            category: details.assetInfo.category
        )
    }

    func cacheKey(for address: Address) -> String {
        address.toRaw().lowercased()
    }
}

private extension NativeSwapAssetClassification {
    init(category: TradingAssetCategory) {
        switch category {
        case .stocks:
            self = .stock
        case .etfs:
            self = .etf
        case .all, .tokens:
            self = .crypto
        }
    }
}

private extension Network {
    var tradeAssetNetworkIdentifier: String {
        switch self {
        case .mainnet:
            return "mainnet"
        case .testnet:
            return "testnet"
        }
    }
}
