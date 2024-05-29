import KeeperCore
import TKLocalize

protocol AccountEventActionContentProvider {
  func title(actionType: HistoryEvent.Action.ActionType) -> String?
}

struct HistoryListAccountEventActionContentProvider: AccountEventActionContentProvider {
  func title(actionType: HistoryEvent.Action.ActionType) -> String? {
    switch actionType {
    case .sent:
      return TKLocales.ActionTypes.sent
    case .receieved:
      return TKLocales.ActionTypes.received
    case .mint:
      return TKLocales.ActionTypes.received
    case .burn:
      return TKLocales.ActionTypes.sent
    case .depositStake:
      return TKLocales.ActionTypes.stake
    case .withdrawStake:
      return TKLocales.ActionTypes.unstake
    case .withdrawStakeRequest:
      return TKLocales.ActionTypes.unstake_request
    case .jettonSwap:
      return TKLocales.ActionTypes.swap
    case .spam:
      return TKLocales.ActionTypes.spam
    case .bounced:
      return TKLocales.ActionTypes.bounced
    case .subscribed:
      return TKLocales.ActionTypes.received
    case .unsubscribed:
      return TKLocales.ActionTypes.unsubscribed
    case .walletInitialized:
      return TKLocales.ActionTypes.wallet_initialize
    case .contractExec:
      return TKLocales.ActionTypes.contract_exec
    case .nftCollectionCreation:
      return TKLocales.ActionTypes.nft_collection_deploy
    case .nftCreation:
      return TKLocales.ActionTypes.nft_deploy
    case .removalFromSale:
      return TKLocales.ActionTypes.nft_sale_removal
    case .nftPurchase:
      return TKLocales.ActionTypes.nft_purchase
    case .bid:
      return TKLocales.ActionTypes.bid
    case .putUpForAuction:
      return TKLocales.ActionTypes.put_up_auction
    case .endOfAuction:
      return TKLocales.ActionTypes.end_auction
    case .putUpForSale:
      return TKLocales.ActionTypes.sent
    case .domainRenew:
      return TKLocales.ActionTypes.domain_renew
    case .unknown:
      return TKLocales.ActionTypes.unknown
    }
  }
}

struct TonConnectConfirmationAccountEventActionContentProvider: AccountEventActionContentProvider {
  func title(actionType: HistoryEvent.Action.ActionType) -> String? {
    switch actionType {
    case .sent:
      return TKLocales.ActionTypes.Future.send
    case .receieved:
      return TKLocales.ActionTypes.Future.receive
    case .mint:
      return TKLocales.ActionTypes.Future.receive
    case .burn:
      return TKLocales.ActionTypes.Future.send
    case .depositStake:
      return TKLocales.ActionTypes.stake
    case .withdrawStake:
      return TKLocales.ActionTypes.unstake
    case .withdrawStakeRequest:
      return TKLocales.ActionTypes.unstake_request
    case .jettonSwap:
      return TKLocales.ActionTypes.swap
    case .spam:
      return TKLocales.ActionTypes.spam
    case .bounced:
      return TKLocales.ActionTypes.bounced
    case .subscribed:
      return TKLocales.ActionTypes.subscribed
    case .unsubscribed:
      return TKLocales.ActionTypes.unsubscribed
    case .walletInitialized:
      return TKLocales.ActionTypes.wallet_initialize
    case .contractExec:
      return TKLocales.ActionTypes.contract_exec
    case .nftCollectionCreation:
      return TKLocales.ActionTypes.nft_collection_deploy
    case .nftCreation:
      return TKLocales.ActionTypes.nft_deploy
    case .removalFromSale:
      return TKLocales.ActionTypes.nft_sale_removal
    case .nftPurchase:
      return TKLocales.ActionTypes.nft_purchase
    case .bid:
      return TKLocales.ActionTypes.bid
    case .putUpForAuction:
      return TKLocales.ActionTypes.put_up_auction
    case .endOfAuction:
      return TKLocales.ActionTypes.end_auction
    case .putUpForSale:
      return TKLocales.ActionTypes.sent
    case .domainRenew:
      return TKLocales.ActionTypes.domain_renew
    case .unknown:
      return TKLocales.ActionTypes.unknown
    }
  }
}
