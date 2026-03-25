import BigInt
import Foundation
import TonSwift
import TronSwift

public enum ProcessedBalanceState: Equatable {
    case current(ProcessedBalance)
    case previous(ProcessedBalance)

    public var balance: ProcessedBalance {
        switch self {
        case let .current(balance):
            return balance
        case let .previous(balance):
            return balance
        }
    }
}

public final class ProcessedBalanceStore: Store<ProcessedBalanceStore.Event, ProcessedBalanceStore.State> {
    public typealias State = [Wallet: ProcessedBalanceState]

    public enum Event {
        case didUpdateProccessedBalance(wallet: Wallet)
    }

    private let walletsStore: WalletsStore
    private let balanceStore: BalanceStore
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let stakingPoolsStore: StakingPoolsStore

    init(
        walletsStore: WalletsStore,
        balanceStore: BalanceStore,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        stakingPoolsStore: StakingPoolsStore
    ) {
        self.walletsStore = walletsStore
        self.balanceStore = balanceStore
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.stakingPoolsStore = stakingPoolsStore
        super.init(state: [:])
        setupObservers()
    }

    override public func createInitialState() -> State {
        let wallets = walletsStore.wallets
        guard !wallets.isEmpty else { return [:] }
        return calculateState(wallets: wallets)
    }

    private func setupObservers() {
        balanceStore.addObserver(self) { observer, event in
            observer.didGetBalanceStoreEvent(event)
        }
        tonRatesStore.addObserver(self) { observer, event in
            observer.didGetTonRateStoreEvent(event)
        }
        stakingPoolsStore.addObserver(self) { observer, event in
            observer.didGetStakingPoolsStoreEvent(event)
        }
    }

    private func didGetBalanceStoreEvent(_ event: BalanceStore.Event) {
        switch event {
        case let .didUpdateBalanceState(wallet):
            updateState(wallets: [wallet])
        }
    }

    private func didGetTonRateStoreEvent(_ event: TonRatesStore.Event) {
        switch event {
        case .didUpdateRates:
            let wallets = walletsStore.wallets
            updateState(wallets: wallets)
        }
    }

    private func didGetStakingPoolsStoreEvent(_ event: StakingPoolsStore.Event) {
        switch event {
        case let .didUpdateStakingPools(wallet):
            updateState(wallets: [wallet])
        }
    }

    private func updateState(wallets: [Wallet]) {
        updateState { [weak self] state in
            guard let self else { return nil }
            let walletsState = self.calculateState(wallets: wallets)
            let updatedState = state.merging(walletsState, uniquingKeysWith: { $1 })
            return StateUpdate(newState: updatedState)
        } completion: { [weak self] _ in
            wallets.forEach { self?.sendEvent(.didUpdateProccessedBalance(wallet: $0)) }
        }
    }

    private func calculateState(wallets: [Wallet]) -> State {
        guard !wallets.isEmpty else { return [:] }
        let balanceStates = balanceStore.state
        let rates = tonRatesStore.state
        let currency = currencyStore.state

        let tonRate = rates.tonRates.first(where: { $0.currency == currency })
        let usdtRate = rates.usdtRates.first(where: { $0.currency == currency })

        var state = State()
        for wallet in wallets {
            guard let walletBalanceState = balanceStates[wallet] else { continue }
            let stakingPools = stakingPoolsStore.state[wallet] ?? []
            state[wallet] = calculateState(
                wallet: wallet,
                balanceState: walletBalanceState,
                tonRates: tonRate,
                usdtRates: usdtRate,
                jettonRates: rates.jettonRates,
                stakingPools: stakingPools,
                currency: currency
            )
        }
        return state
    }

    private func calculateState(
        wallet: Wallet,
        balanceState: WalletBalanceState?,
        tonRates: Rates.Rate?,
        usdtRates: Rates.Rate?,
        jettonRates: [String: [Rates.Rate]],
        stakingPools: [StackingPoolInfo],
        currency: Currency
    ) -> ProcessedBalanceState? {
        guard let balanceState else { return nil }

        let walletBalance = balanceState.walletBalance

        let tonItem = processTonBalance(
            tonBalance: walletBalance.balance.tonBalance,
            tonRates: wallet.network == .mainnet ? tonRates : .none,
            currency: currency
        )

        var jettonsBalance = walletBalance.balance.jettonsBalance
        var stackingBalance = walletBalance.stacking

        var stakingItems = [ProcessedBalanceStakingItem]()
        var jettonItems = [ProcessedBalanceJettonItem]()

        let ethenaItem = processEthenaItem(
            jettonsBalance: &jettonsBalance,
            jettonRates: jettonRates,
            currency: currency
        )

        for jetton in jettonsBalance {
            if StakingJettonMasterAddress.addresses.contains(jetton.item.jettonInfo.address),
               let pool = stakingPools.first(where: { $0.liquidJettonMaster == jetton.item.jettonInfo.address })
            {
                let jettonStakingInfo = walletBalance.stacking.first(where: { $0.pool == pool.address })
                stackingBalance = stackingBalance.filter { $0 != jettonStakingInfo }

                let amount: Int64 = {
                    if let tonRate = jetton.rates[.TON] {
                        let converted = RateConverter().convertToDecimal(
                            amount: jetton.quantity,
                            amountFractionLength: jetton.item.jettonInfo.fractionDigits,
                            rate: tonRate
                        )
                        let convertedFractionLength = min(Int16(TonInfo.fractionDigits), max(Int16(-converted.exponent), 0))
                        return Int64(
                            NSDecimalNumber(decimal: converted)
                                .multiplying(byPowerOf10: convertedFractionLength).doubleValue
                        )
                    } else {
                        return 0
                    }
                }()

                let stakingInfo = AccountStackingInfo(
                    pool: pool.address,
                    amount: amount,
                    pendingDeposit: jettonStakingInfo?.pendingDeposit ?? 0,
                    pendingWithdraw: jettonStakingInfo?.pendingWithdraw ?? 0,
                    readyWithdraw: jettonStakingInfo?.pendingWithdraw ?? 0
                )

                let jettonItem = processJettonBalance(jetton, currency: currency)

                let stakingItem = processStaking(
                    stakingInfo,
                    stakingPool: pool,
                    jetton: jettonItem,
                    tonRates: tonRates,
                    currency: currency
                )

                stakingItems.append(stakingItem)
            } else {
                if jettonItems.contains(where: { $0.jetton.jettonInfo.address == jetton.item.jettonInfo.address }) {
                    continue
                }
                jettonItems.append(processJettonBalance(jetton, currency: currency))
            }
        }

        if let walletAddress = try? wallet.address,
           let item = makeTonUSDTIfNeeded(
               jettonsBalance: jettonsBalance,
               walletAddress: walletAddress,
               usdtRate: usdtRates,
               currency: currency
           )
        {
            jettonItems.append(item)
        }

        stakingItems.append(contentsOf: stackingBalance.map { item in
            let stackingPool = stakingPools.first(where: { $0.address == item.pool })
            return processStaking(
                item,
                stakingPool: stackingPool,
                jetton: nil,
                tonRates: tonRates,
                currency: currency
            )
        })

        var items: [ProcessedBalanceItem] = [.ton(tonItem)]

        var tronUSDTItem: ProcessedBalanceTronUSDTItem?
        if wallet.isTronTurnOn {
            let item = processTronUSDT(
                tronBalance: walletBalance.tronBalance,
                usdtRates: usdtRates,
                currency: currency
            )

            items.append(.tronUSDT(item))
            tronUSDTItem = item
        }

        items.append(contentsOf: stakingItems.map { .staking($0) })
        items.append(contentsOf: jettonItems.map { .jetton($0) })
        items.append(.ethena(ethenaItem))

        let processedBalance = ProcessedBalance(
            items: items,
            tonItem: tonItem,
            tronUSDTItem: tronUSDTItem,
            jettonItems: jettonItems,
            stakingItems: stakingItems,
            batteryBalance: walletBalance.batteryBalance,
            ethenaItem: ethenaItem,
            currency: currency,
            date: walletBalance.date
        )

        switch balanceState {
        case .current:
            return ProcessedBalanceState.current(processedBalance)
        case .previous:
            return ProcessedBalanceState.previous(processedBalance)
        }
    }

    private func processTonBalance(
        tonBalance: TonBalance,
        tonRates: Rates.Rate?,
        currency: Currency
    ) -> ProcessedBalanceTonItem {
        let converted: Decimal
        let price: Decimal
        let diff: String?
        if let tonRate = tonRates {
            converted = RateConverter().convertToDecimal(
                amount: BigUInt(tonBalance.amount),
                amountFractionLength: TonInfo.fractionDigits,
                rate: tonRate
            )
            diff = tonRate.diff24h
            price = tonRate.rate
        } else {
            converted = 0
            diff = nil
            price = 0
        }

        return ProcessedBalanceTonItem(
            id: TonInfo.symbol,
            title: TonInfo.symbol,
            amount: UInt64(tonBalance.amount),
            fractionalDigits: TonInfo.fractionDigits,
            currency: currency,
            converted: converted,
            price: price,
            diff: diff,
            shouldCalculateInTotal: true
        )
    }

    private func processJettonBalance(
        _ jettonBalance: JettonBalance,
        currency: Currency
    ) -> ProcessedBalanceJettonItem {
        let converted: Decimal
        let price: Decimal
        let diff: String?
        if let rate = jettonBalance.rates[currency] {
            converted = RateConverter().convertToDecimal(
                amount: jettonBalance.quantity,
                amountFractionLength: jettonBalance.item.jettonInfo.fractionDigits,
                rate: rate
            )
            diff = rate.diff24h
            price = rate.rate
        } else {
            converted = 0
            diff = nil
            price = 0
        }

        var tag: String?
        if jettonBalance.item.jettonInfo.address == JettonMasterAddress.tonUSDT {
            tag = "TON"
        }

        return ProcessedBalanceJettonItem(
            id: jettonBalance.item.jettonInfo.address.toRaw(),
            jetton: jettonBalance.item,
            amount: jettonBalance.scaledBalance ?? jettonBalance.quantity,
            fractionalDigits: jettonBalance.item.jettonInfo.fractionDigits,
            tag: tag,
            currency: currency,
            converted: converted,
            price: price,
            diff: diff,
            shouldCalculateInTotal: [.whitelist, .graylist].contains(jettonBalance.item.jettonInfo.verification)
        )
    }

    private func processStaking(
        _ stakingInfo: AccountStackingInfo,
        stakingPool: StackingPoolInfo?,
        jetton: ProcessedBalanceJettonItem?,
        tonRates: Rates.Rate?,
        currency: Currency
    ) -> ProcessedBalanceStakingItem {
        var amountConverted: Decimal = 0
        var pendingDepositConverted: Decimal = 0
        var pendingWithdrawConverted: Decimal = 0
        var readyWithdrawConverted: Decimal = 0
        var price: Decimal = 0
        if let tonRate = tonRates {
            amountConverted = RateConverter().convertToDecimal(
                amount: BigUInt(stakingInfo.amount),
                amountFractionLength: TonInfo.fractionDigits,
                rate: tonRate
            )
            pendingDepositConverted = RateConverter().convertToDecimal(
                amount: BigUInt(stakingInfo.pendingDeposit),
                amountFractionLength: TonInfo.fractionDigits,
                rate: tonRate
            )
            pendingWithdrawConverted = RateConverter().convertToDecimal(
                amount: BigUInt(stakingInfo.pendingWithdraw),
                amountFractionLength: TonInfo.fractionDigits,
                rate: tonRate
            )
            readyWithdrawConverted = RateConverter().convertToDecimal(
                amount: BigUInt(stakingInfo.readyWithdraw),
                amountFractionLength: TonInfo.fractionDigits,
                rate: tonRate
            )

            price = tonRate.rate
        }

        return ProcessedBalanceStakingItem(
            id: stakingInfo.pool.toRaw(),
            info: stakingInfo,
            poolInfo: stakingPool,
            jetton: jetton,
            currency: currency,
            amountConverted: amountConverted,
            pendingDepositConverted: pendingDepositConverted,
            pendingWithdrawConverted: pendingWithdrawConverted,
            readyWithdrawConverted: readyWithdrawConverted,
            price: price,
            shouldCalculateInTotal: true
        )
    }

    private func processTronUSDT(
        tronBalance: TronBalance?,
        usdtRates: Rates.Rate?,
        currency: Currency
    ) -> ProcessedBalanceTronUSDTItem {
        let amount = tronBalance?.amount ?? 0
        let converted: Decimal
        let price: Decimal
        let diff: String?
        if let rate = usdtRates {
            converted = RateConverter().convertToDecimal(
                amount: amount,
                amountFractionLength: USDT.fractionDigits,
                rate: rate
            )
            diff = rate.diff24h
            price = rate.rate
        } else {
            converted = 0
            diff = nil
            price = 0
        }

        return ProcessedBalanceTronUSDTItem(
            id: TronSwift.USDT.address.base58,
            amount: amount,
            trxAmount: tronBalance?.trxAmount ?? 0,
            fractionalDigits: TronSwift.USDT.fractionDigits,
            tag: TronSwift.USDT.tag,
            currency: currency,
            converted: converted,
            price: price,
            diff: diff,
            shouldCalculateInTotal: true
        )
    }

    private func makeTonUSDTIfNeeded(
        jettonsBalance: [JettonBalance],
        walletAddress: TonSwift.Address,
        usdtRate: Rates.Rate?,
        currency: Currency
    ) -> ProcessedBalanceJettonItem? {
        let hasTonUSDT = jettonsBalance.contains { $0.item.jettonInfo.isTonUSDT }

        guard !hasTonUSDT else { return nil }

        let jettonInfo = JettonInfo(
            isTransferable: true,
            hasCustomPayload: false,
            address: JettonMasterAddress.tonUSDT,
            fractionDigits: USDT.fractionDigits,
            name: "Tether USD",
            symbol: USDT.symbol,
            verification: .whitelist,
            imageURL: USDT.imageURL
        )
        let jettonItem = JettonItem(
            jettonInfo: jettonInfo,
            walletAddress: walletAddress
        )
        let rates = usdtRate.map { [$0.currency: $0] } ?? [:]
        return processJettonBalance(
            JettonBalance(
                item: jettonItem,
                quantity: BigUInt(0),
                rates: rates
            ),
            currency: currency
        )
    }

    private func processEthenaItem(
        jettonsBalance: inout [JettonBalance],
        jettonRates: [String: [Rates.Rate]],
        currency: Currency
    ) -> ProcessedBalanceEthenaItem {
        var amount: BigUInt = 0
        var converted: Decimal = 0

        var stakedAmount: BigUInt = 0
        var stakedConverted: Decimal = 0

        var usdeRates: Rates.Rate?
        var tsUsdeRates: Rates.Rate?

        let rateConverter = RateConverter()

        var usdeJettonBalance: JettonBalance?
        if let index = jettonsBalance.firstIndex(where: { $0.item.jettonInfo.isUSDe }) {
            usdeJettonBalance = jettonsBalance.remove(at: index)
            usdeRates = usdeJettonBalance?.rates[currency] ?? jettonRates[JettonMasterAddress.USDe.toRaw()]?.first(where: { $0.currency == currency })
        } else {
            usdeRates = jettonRates[JettonMasterAddress.USDe.toRaw()]?.first(where: { $0.currency == currency })
        }

        var stakedUsdeJettonBalance: JettonBalance?
        if let index = jettonsBalance.firstIndex(where: { $0.item.jettonInfo.isTsUSDe }) {
            stakedUsdeJettonBalance = jettonsBalance.remove(at: index)
            tsUsdeRates = stakedUsdeJettonBalance?.rates[currency]
        } else {
            tsUsdeRates = jettonRates[JettonMasterAddress.tsUSDe.toRaw()]?.first(where: { $0.currency == currency })
        }

        var usdeJettonItem: ProcessedBalanceJettonItem?
        if let usdeJettonBalance {
            let jettonItem = processJettonBalance(usdeJettonBalance, currency: currency)
            amount += jettonItem.amount
            usdeJettonItem = jettonItem
        }

        var tsUsdeJettonItem: ProcessedBalanceJettonItem?
        if let stakedUsdeJettonBalance {
            let jettonItem = processJettonBalance(stakedUsdeJettonBalance, currency: currency)
            tsUsdeJettonItem = jettonItem

            if let usdeRates, let tsUsdeRates {
                let converted = rateConverter.convertJetton(
                    amount: stakedUsdeJettonBalance.quantity,
                    fromRate: tsUsdeRates,
                    toRate: usdeRates
                )
                stakedAmount = converted
                amount += converted
            }
        }

        if let usdeRates {
            converted = rateConverter
                .convertToDecimal(
                    amount: amount,
                    amountFractionLength: USDe.fractionDigits,
                    rate: usdeRates
                )
            stakedConverted = rateConverter
                .convertToDecimal(
                    amount: stakedAmount,
                    amountFractionLength: USDe.fractionDigits,
                    rate: usdeRates
                )
        }

        return ProcessedBalanceEthenaItem(
            usde: usdeJettonItem,
            stakedUsde: tsUsdeJettonItem,
            amount: amount,
            stakedAmount: stakedAmount,
            fractionalDigits: USDe.fractionDigits,
            tag: nil,
            currency: currency,
            converted: converted,
            stakedConverted: stakedConverted,
            price: usdeRates?.rate ?? 0,
            diff: usdeRates?.diff24h ?? ""
        )
    }
}

private enum StakingJettonMasterAddress {
    static var addresses: [TonSwift.Address] {
        [
            // Tonstakers
            try! Address.parse("0:bdf3fa8098d129b54b4f73b5bac5d1e1fd91eb054169c3916dfc8ccd536d1000"),
        ]
    }
}
