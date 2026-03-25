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
        mode: Mode
    ) {
        self.wallet = wallet
        self.selectedToken = selectedToken
        self.balanceStore = balanceStore
        self.currencyStore = currencyStore
        self.swapAssetsStore = swapAssetsStore
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

        switch mode {
        case .send:
            let filteredJettons = balance.jettonsBalance
                .filter {
                    !$0.jettonBalance.quantity.isZero
                }
                .filter {
                    availableAddresses.contains($0.jettonBalance.item.jettonInfo.address.toRaw())
                }

            return TokenPickerModelState(
                wallet: wallet,
                tonBalance: balance.tonBalance,
                jettonBalances: filteredJettons,
                tronUSDTBalance: nil,
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

                    jettonBalances.append(item)
                }
            }

            return TokenPickerModelState(
                wallet: wallet,
                tonBalance: balance.tonBalance,
                jettonBalances: jettonBalances,
                tronUSDTBalance: nil,
                selectedToken: selectedToken,
                scrollToSelected: scrollToSelected,
                mode: .name
            )
        }
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
