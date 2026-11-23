import BigInt
import Foundation
import KeeperCore
import TKFeatureFlags
import TonSwift

final class BatteryRefillRechargeMethodsModel {
    enum RechargeMethodItem {
        case asset(BatteryRechargeAsset)
        case token(token: TonToken)
        case gift(token: TonToken)

        var identifier: String {
            switch self {
            case let .asset(asset): return asset.method.assetId
            case let .token(token):
                return token.identifier
            case .gift:
                return "gift_identifier"
            }
        }

        var token: TonToken? {
            switch self {
            case .asset: return nil
            case let .token(token):
                return token
            case let .gift(token):
                return token
            }
        }
    }

    enum State {
        case loading(items: [RechargeMethodItem] = [])
        case idle(items: [RechargeMethodItem])
    }

    var stateHandler: ((State) -> Void)?
    private(set) var state: State = .loading() {
        didSet {
            stateHandler?(state)
        }
    }

    private var rechargeMethods = [RechargeMethodItem]()
    private var loadingTask: Task<Void, Never>?
    private var loadingRevision = 0
    private let wallet: Wallet
    private let rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider
    private let configuration: Configuration

    init(
        wallet: Wallet,
        rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.rechargeMethodsProvider = rechargeMethodsProvider
        self.configuration = configuration
    }

    func loadMethods() {
        loadingRevision += 1
        let revision = loadingRevision
        guard !configuration.isDisableBatteryCryptoRechargeModule(network: wallet.network) else {
            loadingTask?.cancel()
            loadingTask = nil
            state = .idle(items: [])
            return
        }

        if let loadingTask = loadingTask {
            loadingTask.cancel()
        }
        let task = Task { [weak self] in
            guard let self else { return }
            let cached = await rechargeMethodsProvider.cachedAssetRechargeItems()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.loadingRevision == revision else { return }
                let previous = self.rechargeMethods.map { item -> RechargeMethodItem in
                    guard case var .asset(asset) = item else { return item }
                    asset.isReady = false
                    return .asset(asset)
                }
                let identifiers = Set(previous.map(\.identifier))
                self.state = .loading(items: previous + cached.filter { !identifiers.contains($0.identifier) })
            }
            let methods = await rechargeMethodsProvider.getAllRechargeMethods()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.loadingRevision == revision else { return }
                self.rechargeMethods = methods
                self.loadingTask = nil
                self.state = .idle(items: methods)
            }
        }
        self.loadingTask = task
    }

    @MainActor
    func loadedItems() async -> [RechargeMethodItem] {
        while let loadingTask {
            await loadingTask.value
        }
        switch state {
        case let .loading(items), let .idle(items): return items
        }
    }
}
