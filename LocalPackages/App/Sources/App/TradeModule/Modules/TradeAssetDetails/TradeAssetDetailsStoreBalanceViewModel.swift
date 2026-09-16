import BigInt
import Combine
import Foundation
import KeeperCore
import TronSwift

@MainActor
final class TradeAssetDetailsStoreBalanceViewModel: ObservableObject, TradeAssetDetailsBalanceViewModeling {
    @Published private(set) var state: TradeAssetDetailsBalanceSnapshot?
    @Published private(set) var visibility: TradeAssetDetailsAssetVisibility?

    private let wallet: Wallet?
    private let assetID: String
    private let typedAssetId: TradingAssetToken
    private let balanceLoader: BalanceLoader
    private let convertedBalanceStore: ConvertedBalanceStore
    private let multichainAssetBalanceProvider: MultichainAssetBalanceProvider
    private let freshnessModel = BalanceFreshnessModel()

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
        typedAssetId: TradingAssetToken,
        balanceLoader: BalanceLoader,
        convertedBalanceStore: ConvertedBalanceStore,
        multichainAssetBalanceProvider: MultichainAssetBalanceProvider
    ) {
        self.wallet = wallet
        self.assetID = assetID
        self.typedAssetId = typedAssetId
        self.balanceLoader = balanceLoader
        self.convertedBalanceStore = convertedBalanceStore
        self.multichainAssetBalanceProvider = multichainAssetBalanceProvider

        convertedBalanceStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateConvertedBalance(wallet):
                Task { @MainActor in
                    observer.handleBalanceUpdate(wallet: wallet)
                }
            }
        }

        balanceLoader.addUpdateObserver(self) { observer, update in
            Task { @MainActor in
                observer.handleBalanceLoaderUpdate(update)
            }
        }

        freshnessModel.didUpdateFreshness = { [weak self] _ in
            self?.state = self?.storeSnapshot()
        }

        freshnessModel.onNeedsRefresh = { [weak self] in
            self?.reload()
        }
    }

    deinit {
        task?.cancel()
    }

    func scheduleUpdate() {
        primeCache()
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

private extension TradeAssetDetailsStoreBalanceViewModel {
    func handleBalanceLoaderUpdate(_ update: BalanceLoaderUpdate) {
        guard update.wallet == wallet, let result = update.result, case .delivered = result else {
            return
        }
        freshnessModel.markFresh()
    }

    func handleBalanceUpdate(wallet: Wallet) {
        guard wallet == self.wallet else {
            return
        }
        state = storeSnapshot()
        visibility = cachedVisibility()
    }

    func primeCache() {
        state = storeSnapshot()
        visibility = cachedVisibility()
    }

    func reload() {
        guard let wallet else {
            return
        }

        // The row renders a cache that outlives the launch and shimmers until a load confirms it,
        // so this is a wait someone is watching rather than a background top-up.
        Task { [balanceLoader] in
            await balanceLoader.reloadBalance(wallet: wallet, priority: .userVisible)
        }

        task?.cancel()
        task = Task { [weak self] in
            await self?.refreshVisibility()
        }
    }

    func refreshVisibility() async {
        let visibility = await loadVisibility()
        guard !Task.isCancelled else {
            return
        }
        self.visibility = visibility
    }
}

private extension TradeAssetDetailsStoreBalanceViewModel {
    func storeSnapshot() -> TradeAssetDetailsBalanceSnapshot? {
        guard
            let wallet,
            let convertedBalance = convertedBalanceStore.getState()[wallet]?.balance
        else {
            return nil
        }

        return makeSnapshot(convertedBalance: convertedBalance, identifier: typedAssetId)
    }

    func cachedVisibility() -> TradeAssetDetailsAssetVisibility? {
        guard let wallet, case .multichain = wallet.multichain else {
            return nil
        }
        return multichainAssetBalanceProvider
            .cachedAsset(for: assetID, wallet: wallet)
            .map(TradeAssetDetailsAssetVisibility.init(asset:))
    }

    func loadVisibility() async -> TradeAssetDetailsAssetVisibility? {
        guard let wallet, case .multichain = wallet.multichain else {
            return nil
        }
        guard let asset = await multichainAssetBalanceProvider.loadAsset(
            for: assetID,
            wallet: wallet,
            includingHidden: true
        ) else {
            return cachedVisibility()
        }
        return TradeAssetDetailsAssetVisibility(asset: asset)
    }
}

private extension TradeAssetDetailsStoreBalanceViewModel {
    func makeSnapshot(
        convertedBalance: ConvertedBalance,
        identifier: TradingAssetToken
    ) -> TradeAssetDetailsBalanceSnapshot? {
        switch identifier {
        case .ton:
            let item = convertedBalance.tonBalance
            return TradeAssetDetailsBalanceSnapshot(
                symbol: TonInfo.symbol,
                imageURL: nil,
                amount: BigUInt(max(item.tonBalance.amount, 0)),
                fractionDigits: TonInfo.fractionDigits,
                convertedAmount: convertedAmount(value: item.converted, price: item.price),
                tagText: nil,
                freshness: freshnessModel.freshness
            )

        case let .jetton(address):
            guard let item = convertedBalance.jettonsBalance.first(where: {
                $0.jettonBalance.item.jettonInfo.address == address
            }) else {
                return nil
            }
            let jettonInfo = item.jettonBalance.item.jettonInfo
            let displayAmount = item.jettonBalance.scaledBalance ?? item.jettonBalance.quantity
            return TradeAssetDetailsBalanceSnapshot(
                symbol: jettonInfo.symbol ?? "",
                imageURL: jettonInfo.imageURL,
                amount: displayAmount,
                fractionDigits: jettonInfo.fractionDigits,
                convertedAmount: convertedAmount(value: item.converted, price: item.price),
                tagText: jettonInfo.tag,
                freshness: freshnessModel.freshness
            )

        case .tronUsdt:
            guard let item = convertedBalance.tronUSDT else {
                return nil
            }
            return TradeAssetDetailsBalanceSnapshot(
                symbol: TronSwift.USDT.symbol,
                imageURL: TronSwift.USDT.imageURL,
                amount: item.amount,
                fractionDigits: TronSwift.USDT.fractionDigits,
                convertedAmount: convertedAmount(value: item.converted, price: item.price),
                tagText: TronSwift.USDT.tag,
                freshness: freshnessModel.freshness
            )

        case .tronTrx:
            guard let item = convertedBalance.tronTRX else {
                return nil
            }
            return TradeAssetDetailsBalanceSnapshot(
                symbol: TronSwift.TRX.symbol,
                imageURL: nil,
                amount: item.amount,
                fractionDigits: TronSwift.TRX.fractionDigits,
                convertedAmount: convertedAmount(value: item.converted, price: item.price),
                tagText: nil,
                freshness: freshnessModel.freshness
            )
        }
    }

    /// The store encodes "no rate available" as a zero price (and a zero converted
    /// value). Preserve the previous behaviour of hiding the fiat line in that case
    /// instead of rendering a misleading "0".
    func convertedAmount(value: Decimal, price: Decimal) -> Decimal? {
        price == 0 ? nil : value
    }
}
