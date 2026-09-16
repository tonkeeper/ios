import Combine
import Foundation
import KeeperCore

@MainActor
final class TradeAssetDetailsMultichainBalanceViewModel: ObservableObject, TradeAssetDetailsBalanceViewModeling {
    @Published private(set) var state: TradeAssetDetailsBalanceSnapshot?
    @Published private(set) var visibility: TradeAssetDetailsAssetVisibility?

    private let wallet: Wallet?
    private let assetID: String
    private let multichainAssetBalanceProvider: MultichainAssetBalanceProvider
    private let balanceLoader: BalanceLoader
    private let currencyProvider: () -> Currency?
    private let isMultichainTransferSupported: (MultichainAsset) -> Bool
    private let freshnessModel = BalanceFreshnessModel()
    private let rateConverter = RateConverter()

    private var task: Task<Void, Never>?

    var statePublisher: AnyPublisher<TradeAssetDetailsBalanceSnapshot?, Never> {
        $state.eraseToAnyPublisher()
    }

    var visibilityPublisher: AnyPublisher<TradeAssetDetailsAssetVisibility?, Never> {
        $visibility.eraseToAnyPublisher()
    }

    init(
        wallet: Wallet?,
        assetID: String,
        multichainAssetBalanceProvider: MultichainAssetBalanceProvider,
        balanceLoader: BalanceLoader,
        hotWindow: TradeAssetDetailsHotWindow,
        currencyProvider: @escaping () -> Currency?,
        isMultichainTransferSupported: @escaping (MultichainAsset) -> Bool
    ) {
        self.wallet = wallet
        self.assetID = assetID
        self.multichainAssetBalanceProvider = multichainAssetBalanceProvider
        self.balanceLoader = balanceLoader
        self.currencyProvider = currencyProvider
        self.isMultichainTransferSupported = isMultichainTransferSupported

        balanceLoader.addUpdateObserver(self) { observer, update in
            Task { @MainActor in
                observer.handleBalanceLoaderUpdate(update)
            }
        }

        if let wallet {
            hotWindow.addObserver(self, wallet: wallet)
        }

        freshnessModel.didUpdateFreshness = { [weak self] _ in
            guard let self else { return }
            apply(asset: cachedAsset())
        }

        freshnessModel.onNeedsRefresh = { [weak self] in
            self?.reload()
        }
    }

    deinit {
        task?.cancel()
    }

    func scheduleUpdate() {
        apply(asset: cachedAsset())
        reload()
    }

    func didAppear() {
        freshnessModel.didAppear()
    }

    func didDisappear() {
        freshnessModel.didDisappear()
    }

    func applyVisibility(_ state: TradeAssetDetailsVisibilityState) {
        guard let visibility else {
            return
        }
        self.visibility = visibility.applying(
            state,
            wallet: wallet,
            provider: multichainAssetBalanceProvider
        )
    }
}

private extension TradeAssetDetailsMultichainBalanceViewModel {
    /// A result rather than a start edge: the run has landed, and whatever moved the wallet's TON
    /// balance may have moved this asset too. What it says about freshness is nothing — that is the
    /// listing's own answer to give.
    func handleBalanceLoaderUpdate(_ update: BalanceLoaderUpdate) {
        guard update.wallet == wallet, update.result != nil else {
            return
        }
        reload()
    }

    func reload() {
        startReload()
    }

    /// One refresh in flight at a time. The hot window waits on the task it starts, so its cadence
    /// is spacing between finished refreshes rather than a queue of overlapping ones.
    @discardableResult
    func startReload() -> Task<Void, Never>? {
        guard wallet != nil else {
            return nil
        }

        task?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await refreshAsset()
        }
        self.task = task
        return task
    }

    func refreshAsset() async {
        let result = await reloadAsset()
        guard !Task.isCancelled else {
            return
        }
        if case .delivered = result {
            freshnessModel.markFresh()
        }
        apply(asset: result.asset)
    }
}

extension TradeAssetDetailsMultichainBalanceViewModel: TradeAssetDetailsHotWindowObserver {
    func hotWindowDidTick() async {
        await startReload()?.value
    }
}

private extension TradeAssetDetailsMultichainBalanceViewModel {
    func cachedAsset() -> MultichainAsset? {
        guard let wallet else {
            return nil
        }
        return multichainAssetBalanceProvider.cachedAsset(
            for: assetID,
            wallet: wallet,
            includingHidden: true
        )
    }

    func reloadAsset() async -> MultichainAssetRefreshResult {
        guard let wallet else {
            return .cached(nil)
        }
        return await multichainAssetBalanceProvider.reloadAsset(
            for: assetID,
            wallet: wallet,
            includingHidden: true
        )
    }

    func apply(asset: MultichainAsset?) {
        state = asset.flatMap(makeSnapshotIfTransferSupported(asset:))
        visibility = asset.map(TradeAssetDetailsAssetVisibility.init(asset:))
    }

    func makeSnapshotIfTransferSupported(asset: MultichainAsset) -> TradeAssetDetailsBalanceSnapshot? {
        guard isMultichainTransferSupported(asset) else {
            return nil
        }

        return TradeAssetDetailsBalanceSnapshot(
            symbol: asset.asset.symbol,
            imageURL: URL(string: asset.asset.image),
            amount: asset.balance,
            fractionDigits: asset.asset.decimals,
            convertedAmount: convertedAmount(asset: asset),
            tagText: nil,
            freshness: freshnessModel.freshness
        )
    }

    func convertedAmount(asset: MultichainAsset) -> Decimal? {
        guard let currency = currencyProvider() else {
            return nil
        }
        let price = asset.price.prices[currency.code]
            ?? asset.price.prices[currency.code.lowercased()]
            ?? asset.price.prices[currency.code.uppercased()]
        guard let price else {
            return nil
        }
        let rate = Rates.Rate(
            currency: currency,
            rate: Decimal(price),
            diff24h: nil
        )
        return rateConverter.convertToDecimal(
            amount: asset.balance,
            amountFractionLength: asset.asset.decimals,
            rate: rate
        )
    }
}
