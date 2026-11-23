import Foundation
import KeeperCore
import Perps
import PerpsModels
import TKCore

extension AnalyticsProvider {
    func log(_ event: PerpsAnalyticsEvent, wallet: Wallet) {
        switch event {
        case let .depositStarted(eligibleAssetsCount):
            log(PerpsDepositStarted(walletMode: WalletMode(wallet: wallet), eligibleAssetsCount: eligibleAssetsCount))
        case let .depositContinueClicked(assetId, amountUsd):
            log(PerpsDepositContinueClicked(asset: assetId, amountBucket: amountUsd.map(BalanceBucket.init(usd:))))
        case let .depositFailed(failure, step):
            log(PerpsDepositFailed(screen: PerpsDepositFailed.Screen(step), errorType: PerpsDepositFailed.ErrorType(failure)))
        case let .depositConfirmed(entry, assetId, operationId):
            log(PerpsDepositConfirmed(
                sourceScreen: PerpsDepositConfirmed.SourceScreen(entry),
                asset: assetId,
                operationId: operationId
            ))
        case let .orderSubmitted(order, clientOrderIndex):
            log(PerpsOrderSubmitted(
                side: order.side == .long ? .long : .short,
                asset: PerpsMarketAssetID.make(marketId: order.marketId),
                leverage: order.leverage,
                orderType: order.isLimit ? .limit : .market,
                clientOrderIndex: clientOrderIndex
            ))
        case let .tradingDataError(marketId):
            log(PerpsTradingDataError(asset: PerpsMarketAssetID.make(marketId: marketId)))
        }
    }
}

extension PerpsDepositConfirmed.SourceScreen {
    init(_ entry: PerpsDepositEntry) {
        switch entry {
        case .home: self = .perpsHome
        case .openPosition: self = .openPosition
        case .addToPosition: self = .addToPosition
        case .addMargin: self = .addMargin
        }
    }
}

extension BalanceBucket {
    init(usd: Decimal) {
        switch usd {
        case ...0: self = ._0
        case ..<1: self = ._01
        case ..<10: self = ._110
        case ..<100: self = ._10100
        case ..<1000: self = ._1001k
        case ..<10000: self = ._1k10k
        case ..<100_000: self = ._10k100k
        default: self = ._100kPlus
        }
    }
}

extension PerpsDepositFailed.Screen {
    init(_ step: PerpsDepositStep) {
        switch step {
        case .amount: self = .amount
        case .confirm: self = .confirm
        case .background: self = .background
        }
    }
}

extension PerpsDepositFailed.ErrorType {
    init(_ failure: PerpsDepositFailure) {
        switch failure {
        case .belowMinimum: self = .belowMinimum
        case .insufficientBalance: self = .insufficientBalance
        case .insufficientNetworkFee: self = .insufficientNetworkFee
        case .quoteExpired: self = .quoteExpired
        case .quoteChanged: self = .quoteChanged
        case .depositInProgress: self = .depositInProgress
        case .addressBlocked: self = .addressBlocked
        case .failed: self = .failed
        }
    }
}
