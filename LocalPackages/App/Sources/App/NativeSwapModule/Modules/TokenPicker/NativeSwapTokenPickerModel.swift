import BigInt
import Foundation
import KeeperCore
import TonSwift

final class NativeSwapTokenPickerModel: TokenPickerModel {
    var didUpdateState: ((TokenPickerModelState?) -> Void)?

    private let wallet: Wallet
    private let selectedToken: TokenPickerModelState.PickerToken
    private let balanceStore: ConvertedBalanceStore
    private let swapAssetsStore: SwapAssetsStore
    private let currencyStore: CurrencyStore
    private let counterpartToken: KeeperCore.Token
    private let tokenizedAssetResolver: NativeSwapTokenizedAssetResolver
    private let mode: Mode

    enum Mode {
        case send
        case receive
    }

    init(
        wallet: Wallet,
        selectedToken: TokenPickerModelState.PickerToken,
        balanceStore: ConvertedBalanceStore,
        currencyStore: CurrencyStore,
        swapAssetsStore: SwapAssetsStore,
        counterpartToken: KeeperCore.Token,
        tokenizedAssetResolver: NativeSwapTokenizedAssetResolver,
        mode: Mode
    ) {
        self.wallet = wallet
        self.selectedToken = selectedToken
        self.balanceStore = balanceStore
        self.currencyStore = currencyStore
        self.swapAssetsStore = swapAssetsStore
        self.counterpartToken = counterpartToken
        self.tokenizedAssetResolver = tokenizedAssetResolver
        self.mode = mode

        balanceStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateConvertedBalance(wallet):
                guard wallet == observer.wallet else { return }
                Task {
                    await observer.didUpdateBalanceState()
                }
            }
        }

        swapAssetsStore.addObserver(self) { [weak self] _, event in
            switch event {
            case .didUpdateAssets:
                Task {
                    await self?.didUpdateBalanceState()
                }
            }
        }
    }

    func getState() -> TokenPickerModelState? {
        let balanceState = balanceStore.state[wallet]
        return getState(balanceState: balanceState, scrollToSelected: true)
    }
}

private extension NativeSwapTokenPickerModel {
    func didUpdateBalanceState() async {
        let balanceState = balanceStore.state[wallet]
        let state = getState(balanceState: balanceState, scrollToSelected: true)
        self.didUpdateState?(state)
    }

    func getState(
        balanceState: ConvertedBalanceState?,
        scrollToSelected: Bool
    ) -> TokenPickerModelState? {
        guard let balance = balanceState?.balance else { return nil }
        guard let walletAddress = try? wallet.address else { return nil }

        let availableAddresses = Set(swapAssetsStore.state.map { $0.address })
        let tonBalance = tokenAllowed(.ton(.ton)) ? balance.tonBalance : nil

        switch mode {
        case .send:
            let filteredJettons = balance.jettonsBalance
                .filter {
                    !$0.jettonBalance.quantity.isZero
                }
                .filter {
                    availableAddresses.contains($0.jettonBalance.item.jettonInfo.address.toRaw())
                }
                .filter {
                    tokenAllowed(.ton(.jetton($0.jettonBalance.item)))
                }

            return TokenPickerModelState(
                wallet: wallet,
                tonBalance: tonBalance,
                jettonBalances: filteredJettons,
                tronUSDTBalance: nil,
                tronTRXBalance: nil,
                selectedToken: selectedToken,
                scrollToSelected: scrollToSelected,
                mode: .balance(showConverted: true, currency: currencyStore.state)
            )
        case .receive:
            let currency = currencyStore.state
            var jettonBalances: [ConvertedJettonBalance] = []

            for asset in swapAssetsStore.state {
                if let address = try? Address.parse(asset.address) {
                    let jettonInfo = JettonInfo(
                        isTransferable: true,
                        hasCustomPayload: false,
                        address: address,
                        fractionDigits: asset.decimals,
                        name: asset.name,
                        symbol: asset.symbol,
                        verification: .whitelist,
                        imageURL: asset.image
                    )

                    let jettonItem = JettonItem(
                        jettonInfo: jettonInfo,
                        walletAddress: walletAddress
                    )

                    let rate = asset.rates?[currency]
                    let rates: [Currency: Rates.Rate] = rate.map { [currency: $0] } ?? [:]
                    let quantity = balance.jettonsBalance
                        .first(where: { $0.jettonBalance.item.jettonInfo.address == address })?
                        .jettonBalance.quantity ?? BigUInt(0)

                    let item = calculateJettonBalance(
                        JettonBalance(
                            item: jettonItem,
                            quantity: quantity,
                            rates: rates
                        ),
                        currency: currency
                    )

                    if tokenAllowed(.ton(.jetton(jettonItem))) {
                        jettonBalances.append(item)
                    }
                }
            }

            return TokenPickerModelState(
                wallet: wallet,
                tonBalance: tonBalance,
                jettonBalances: jettonBalances,
                tronUSDTBalance: nil,
                tronTRXBalance: nil,
                selectedToken: selectedToken,
                scrollToSelected: scrollToSelected,
                mode: .name
            )
        }
    }

    private func tokenAllowed(_ token: KeeperCore.Token) -> Bool {
        let tokenClassification = tokenizedAssetResolver.cachedClassification(for: token)
        let counterpartClassification = tokenizedAssetResolver.cachedClassification(for: counterpartToken)

        guard let tokenClassification else {
            if let counterpartClassification, counterpartClassification.isTokenized {
                return counterpartToken.isSPYx
                    ? token.isTON || token.isTonUSDT
                    : token.isTonUSDT
            }
            return true
        }

        guard let counterpartClassification else {
            return true
        }

        return NativeSwapPairRules.isAllowed(
            fromToken: mode == .send ? token : counterpartToken,
            toToken: mode == .send ? counterpartToken : token,
            fromClassification: mode == .send ? tokenClassification : counterpartClassification,
            toClassification: mode == .send ? counterpartClassification : tokenClassification
        )
    }

    private func calculateJettonBalance(
        _ jettonBalance: JettonBalance,
        currency: Currency
    ) -> ConvertedJettonBalance {
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

        return ConvertedJettonBalance(
            jettonBalance: jettonBalance,
            converted: converted,
            price: price,
            diff: diff
        )
    }
}
