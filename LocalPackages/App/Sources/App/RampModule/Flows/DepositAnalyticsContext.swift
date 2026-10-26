import Foundation
import KeeperCore
import TKCore

typealias DepositAnalyticsSource = RampSource
typealias DepositAddFundsOption = AddFundsOption

extension RampSource {
    var depositOpen: DepositOpen.From {
        switch self {
        case .walletScreen, .historyScreen, .browser, .collectibles, .perps, .walletconnect, .tonconnect, .staking, .migration, .other: .walletScreen
        case .jettonScreen: .jettonScreen
        case .deepLink: .deepLink
        case .qrCode: .qrCode
        }
    }

    var depositClickReceiveTokens: DepositClickReceiveTokens.From {
        switch self {
        case .walletScreen, .historyScreen, .browser, .collectibles, .perps, .walletconnect, .tonconnect, .staking, .migration, .other: .walletScreen
        case .jettonScreen: .jettonScreen
        case .deepLink: .deepLink
        case .qrCode: .qrCode
        }
    }

    func makeDepositViewReceiveTokens(token: Token, walletMode: WalletMode) -> DepositViewReceiveTokens {
        DepositViewReceiveTokens(
            from: self,
            walletMode: walletMode,
            addFundsOption: .receiveTokens,
            network: token.depositAnalyticsReceiveNetwork
        )
    }
}

struct DepositFlowContext {
    let source: DepositAnalyticsSource
    let utm: UtmParameters
    let walletMode: WalletMode
    var addFundsOption: DepositAddFundsOption?
    var buyAsset: String?
    var sellAsset: String?
    var stablecoinSymbol: String?
    var paymentMethod: String?
    var providerName: String?
    var amount: Float?
    var txId: String?
}

extension DepositFlowContext {
    func makeDepositStarted(availableOptions: Set<String>) -> DepositStarted {
        DepositStarted(from: source, walletMode: walletMode, availableOptions: availableOptions)
    }

    func makeDepositOptionClick(option: DepositAddFundsOption) -> DepositOptionClick {
        DepositOptionClick(from: source, walletMode: walletMode, addFundsOption: option)
    }

    func makeDepositContinueToP2pMarket() -> DepositContinueToP2pMarket? {
        guard let addFundsOption else { return nil }
        return DepositContinueToP2pMarket(from: source, walletMode: walletMode, addFundsOption: addFundsOption)
    }

    func makeDepositViewBuyTonWithCrypto(availableOptions: Set<String>) -> DepositViewBuyTonWithCrypto? {
        guard let addFundsOption else { return nil }
        return DepositViewBuyTonWithCrypto(
            from: source,
            addFundsOption: addFundsOption,
            availableOptions: availableOptions
        )
    }

    func makeDepositViewSendAsset() -> DepositViewSendAsset? {
        guard let addFundsOption, let sellAsset, let buyAsset else { return nil }
        return DepositViewSendAsset(
            from: source,
            walletMode: walletMode,
            addFundsOption: addFundsOption,
            sellAsset: sellAsset,
            buyAsset: buyAsset
        )
    }

    func makeDepositViewQrCode() -> DepositViewQrCode? {
        guard let addFundsOption, let sellAsset, let buyAsset else { return nil }
        return DepositViewQrCode(
            from: source,
            walletMode: walletMode,
            addFundsOption: addFundsOption,
            sellAsset: sellAsset,
            buyAsset: buyAsset
        )
    }

    func makeDepositViewFiatChooseAsset(availableOptions: Set<String>) -> DepositViewFiatChooseAsset? {
        guard let addFundsOption else { return nil }
        return DepositViewFiatChooseAsset(
            from: source,
            addFundsOption: addFundsOption,
            availableOptions: availableOptions
        )
    }

    func makeDepositClickFiatAsset() -> DepositClickFiatAsset? {
        guard let addFundsOption, let buyAsset else { return nil }
        return DepositClickFiatAsset(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset
        )
    }

    func makeDepositViewFiatPaymentMethod(availableOptions: Set<String>) -> DepositViewFiatPaymentMethod? {
        guard let addFundsOption, let buyAsset, let sellAsset else { return nil }
        return DepositViewFiatPaymentMethod(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset,
            sellAsset: sellAsset,
            availableOptions: availableOptions
        )
    }

    func makeDepositClickFiatPaymentMethod() -> DepositClickFiatPaymentMethod? {
        guard let addFundsOption, let buyAsset, let sellAsset, let paymentMethod else { return nil }
        return DepositClickFiatPaymentMethod(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset,
            sellAsset: sellAsset,
            paymentMethod: paymentMethod
        )
    }

    func makeDepositViewRampInsertAmount() -> DepositViewRampInsertAmount? {
        guard let addFundsOption, let buyAsset, let sellAsset, let paymentMethod, let providerName else { return nil }
        return DepositViewRampInsertAmount(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset,
            sellAsset: sellAsset,
            paymentMethod: paymentMethod,
            providerName: providerName
        )
    }

    func makeDepositClickRampInsertAmountContinue() -> DepositClickRampInsertAmountContinue? {
        guard let addFundsOption, let buyAsset, let sellAsset, let paymentMethod, let providerName, let amount else { return nil }
        return DepositClickRampInsertAmountContinue(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset,
            sellAsset: sellAsset,
            paymentMethod: paymentMethod,
            providerName: providerName,
            amount: amount
        )
    }

    func makeDepositContinueToRampProvider() -> DepositContinueToRampProvider? {
        guard
            let addFundsOption,
            let buyAsset,
            let sellAsset,
            let paymentMethod,
            let providerName,
            let amount,
            let txId
        else {
            return nil
        }
        return DepositContinueToRampProvider(
            from: source,
            walletMode: walletMode,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset,
            sellAsset: sellAsset,
            paymentMethod: paymentMethod,
            providerName: providerName,
            amount: amount,
            txId: txId
        )
    }

    func makeDepositViewChooseStablecoin(availableOptions: Set<String>) -> DepositViewChooseStablecoin? {
        guard let addFundsOption else { return nil }
        return DepositViewChooseStablecoin(
            from: source,
            addFundsOption: addFundsOption,
            availableOptions: availableOptions
        )
    }

    func makeDepositClickStablecoin() -> DepositClickStablecoin? {
        guard let addFundsOption, let buyAsset else { return nil }
        return DepositClickStablecoin(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset
        )
    }

    func makeDepositViewStablecoinPaymentMethod(availableOptions: Set<String>) -> DepositViewStablecoinPaymentMethod? {
        guard let addFundsOption, let buyAsset else { return nil }
        return DepositViewStablecoinPaymentMethod(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset,
            availableOptions: availableOptions
        )
    }

    func makeDepositClickStablecoinPaymentMethod() -> DepositClickStablecoinPaymentMethod? {
        guard let addFundsOption, let buyAsset, let stablecoinSymbol else { return nil }
        return DepositClickStablecoinPaymentMethod(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset,
            stablecoinSymbol: stablecoinSymbol
        )
    }

    func makeDepositViewChooseNetwork(availableOptions: Set<String>) -> DepositViewChooseNetwork? {
        guard let addFundsOption, let buyAsset, let stablecoinSymbol else { return nil }
        return DepositViewChooseNetwork(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset,
            stablecoinSymbol: stablecoinSymbol,
            availableOptions: availableOptions
        )
    }

    func makeDepositClickNetwork() -> DepositClickNetwork? {
        guard let addFundsOption, let buyAsset, let stablecoinSymbol, let sellAsset else { return nil }
        return DepositClickNetwork(
            from: source,
            addFundsOption: addFundsOption,
            buyAsset: buyAsset,
            stablecoinSymbol: stablecoinSymbol,
            sellAsset: sellAsset
        )
    }
}
