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
        case .send, .outgoingFallback, .stake, .burn, .dnsRenew:
            return .outgoing
        case .receive, .incomingFallback, .unstake, .mint:
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
        }
    }
}
