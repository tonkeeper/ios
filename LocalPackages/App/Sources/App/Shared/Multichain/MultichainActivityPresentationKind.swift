import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

enum MultichainActivityPresentationKind: Equatable {
    case send
    case receive
    case swap
    case stake
    case unstake
    case mint
    case burn
    case dnsRenew
    case incomingFallback
    case outgoingFallback
    case perpsOpened(MultichainPerpsSide?)
    case perpsClosed(MultichainPerpsSide?)
    case perpsLiquidated(MultichainPerpsSide?)
    case perpsTakeProfit
    case perpsStopLoss
    case perpsDeposit
    case perpsWithdrawal

    enum AmountSide {
        case incoming
        case outgoing
        case both
    }

    init(activity: MultichainActivity) {
        switch activity.activityType {
        case .send:
            self = .send
        case .receive:
            self = .receive
        case .swap:
            self = .swap
        case .stake:
            self = .stake
        case .unstake:
            self = .unstake
        case .mint:
            self = .mint
        case .burn:
            self = .burn
        case .dnsRenew:
            self = .dnsRenew
        case .perpsPositionOpened:
            self = .perpsOpened(activity.perps?.side)
        case .perpsPositionClosed:
            switch activity.perps?.closeReason {
            case .liquidation:
                self = .perpsLiquidated(activity.perps?.side)
            case .takeProfit:
                self = .perpsTakeProfit
            case .stopLoss:
                self = .perpsStopLoss
            case .manual, nil:
                self = .perpsClosed(activity.perps?.side)
            }
        case .perpsBalanceDeposit:
            self = .perpsDeposit
        case .perpsBalanceWithdrawal:
            self = .perpsWithdrawal
        case .approve, .revoke, .bridge, .claim, .wrap, .unwrap, .deploy, .contractCall,
             .nftPurchase, .auctionBid, .subscribe, .unsubscribe, .freeze,
             .unfreeze, .delegate, .undelegate, .vote, .supply, .withdraw, .borrow,
             .repay, .airdrop, .unknown:
            self = activity.direction == .incoming ? .incomingFallback : .outgoingFallback
        }
    }

    var title: String {
        switch self {
        case .send, .outgoingFallback:
            return TKLocales.History.Tab.sent
        case .receive, .mint, .incomingFallback:
            return TKLocales.History.Tab.received
        case .swap:
            return TKLocales.ActionTypes.Future.swap
        case .stake:
            return TKLocales.ActionTypes.stake
        case .unstake:
            return TKLocales.ActionTypes.unstake
        case .burn:
            return TKLocales.ActionTypes.burned
        case .dnsRenew:
            return TKLocales.ActionTypes.domainRenew
        case let .perpsOpened(side):
            switch side {
            case .long:
                return TKLocales.MultichainHistory.Perps.openedLong
            case .short:
                return TKLocales.MultichainHistory.Perps.openedShort
            case nil:
                return TKLocales.MultichainHistory.Perps.opened
            }
        case let .perpsClosed(side):
            switch side {
            case .long:
                return TKLocales.MultichainHistory.Perps.closedLong
            case .short:
                return TKLocales.MultichainHistory.Perps.closedShort
            case nil:
                return TKLocales.MultichainHistory.Perps.closed
            }
        case let .perpsLiquidated(side):
            switch side {
            case .long:
                return TKLocales.MultichainHistory.Perps.liquidatedLong
            case .short:
                return TKLocales.MultichainHistory.Perps.liquidatedShort
            case nil:
                return TKLocales.MultichainHistory.Perps.liquidated
            }
        case .perpsTakeProfit:
            return TKLocales.MultichainHistory.Perps.takeProfitExecuted
        case .perpsStopLoss:
            return TKLocales.MultichainHistory.Perps.stopLossExecuted
        case .perpsDeposit:
            return TKLocales.Perps.deposit
        case .perpsWithdrawal:
            return TKLocales.Perps.withdraw
        }
    }

    var pendingTitle: String {
        switch self {
        case .send, .outgoingFallback:
            return TKLocales.ActionTypes.sending
        case .receive, .mint, .incomingFallback:
            return TKLocales.ActionTypes.receiving
        case .swap:
            return TKLocales.ActionTypes.swapping
        case .stake:
            return TKLocales.ActionTypes.staking
        case .unstake:
            return TKLocales.ActionTypes.unstaking
        case .burn:
            return TKLocales.ActionTypes.burning
        case .dnsRenew:
            return TKLocales.ActionTypes.domainRenewing
        case .perpsOpened, .perpsClosed, .perpsLiquidated, .perpsTakeProfit,
             .perpsStopLoss, .perpsDeposit, .perpsWithdrawal:
            return title
        }
    }

    func title(isPending: Bool) -> String {
        isPending ? pendingTitle : title
    }

    var icon: UIImage {
        switch self {
        case .send, .outgoingFallback, .stake, .unstake, .burn:
            return .TKUIKit.Icons.Size28.trayArrowUp
        case .receive, .incomingFallback, .mint:
            return .TKUIKit.Icons.Size28.trayArrowDown
        case .swap:
            return .TKUIKit.Icons.Size28.swapHorizontalAlternative
        case .dnsRenew:
            return .TKUIKit.Icons.Size28.renew
        case .perpsOpened, .perpsClosed:
            return .TKUIKit.Icons.Size28.lock
        case .perpsLiquidated:
            return .TKUIKit.Icons.Size28.fire
        case .perpsTakeProfit:
            return .TKUIKit.Icons.Size28.arrowDownOutline
        case .perpsStopLoss:
            return .TKUIKit.Icons.Size28.arrowUpOutline
        case .perpsDeposit:
            return .TKUIKit.Icons.Size28.trayArrowDown
        case .perpsWithdrawal:
            return .TKUIKit.Icons.Size28.trayArrowUp
        }
    }

    func amountSide(for activity: MultichainActivity) -> AmountSide {
        let hasIncoming = Self.hasAmount(rawAmount: activity.inAmount, token: activity.inToken)
        let hasOutgoing = Self.hasAmount(rawAmount: activity.outAmount, token: activity.outToken)

        switch preferredAmountSide {
        case .incoming:
            return hasOutgoing && !hasIncoming ? .outgoing : .incoming
        case .outgoing:
            return hasIncoming && !hasOutgoing ? .incoming : .outgoing
        case .both:
            switch (hasIncoming, hasOutgoing) {
            case (true, false):
                return .incoming
            case (false, true):
                return .outgoing
            case (true, true), (false, false):
                return .both
            }
        }
    }

    private var preferredAmountSide: AmountSide {
        switch self {
        case .send, .outgoingFallback, .stake, .burn, .dnsRenew, .perpsWithdrawal:
            return .outgoing
        case .receive, .incomingFallback, .unstake, .mint, .perpsDeposit,
             .perpsOpened, .perpsClosed, .perpsLiquidated, .perpsTakeProfit, .perpsStopLoss:
            return .incoming
        case .swap:
            return .both
        }
    }

    private static func hasAmount(rawAmount: String?, token: MultichainAssetDetails?) -> Bool {
        guard token != nil, let rawAmount else {
            return false
        }
        return !rawAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func detailsDateTitle(date: String) -> String {
        switch self {
        case .send, .outgoingFallback:
            return TKLocales.EventDetails.sentOn(date)
        case .burn:
            return TKLocales.EventDetails.burnedOn(date)
        case .receive, .incomingFallback, .mint:
            return TKLocales.EventDetails.receivedOn(date)
        case .swap:
            return TKLocales.EventDetails.swappedOn(date)
        case .stake:
            return TKLocales.EventDetails.stakedOn(date)
        case .unstake:
            return TKLocales.EventDetails.unstakeOn(date)
        case .dnsRenew:
            return TKLocales.EventDetails.renewedOn(date)
        case .perpsOpened, .perpsClosed, .perpsLiquidated, .perpsTakeProfit,
             .perpsStopLoss, .perpsDeposit, .perpsWithdrawal:
            return date
        }
    }
}
