import KeeperCore
import TKLocalize

protocol AccountEventActionContentProvider {
  func title(actionType: AccountEventModel.Action.ActionType) -> String?
}

struct HistoryListAccountEventActionContentProvider: AccountEventActionContentProvider {
  func title(actionType: AccountEventModel.Action.ActionType) -> String? {
    switch actionType {
    case .sent:
      return TKLocales.ActionTypes.sent
    case .receieved:
      return TKLocales.ActionTypes.received
    case .mint:
      return TKLocales.ActionTypes.received
    case .burn:
      return TKLocales.ActionTypes.burned
    case .depositStake:
      return TKLocales.ActionTypes.stake
    case .withdrawStake:
      return TKLocales.ActionTypes.unstake
    case .withdrawStakeRequest:
      return TKLocales.ActionTypes.unstakeRequest
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
      return TKLocales.ActionTypes.walletInitialize
    case .contractExec:
      return TKLocales.ActionTypes.contractExec
    case .nftCollectionCreation:
      return TKLocales.ActionTypes.nftCollectionDeploy
    case .nftCreation:
      return TKLocales.ActionTypes.nftDeploy
    case .removalFromSale:
      return TKLocales.ActionTypes.nftSaleRemoval
    case .nftPurchase:
      return TKLocales.ActionTypes.nftPurchase
    case .bid:
      return TKLocales.ActionTypes.bid
    case .putUpForAuction:
      return TKLocales.ActionTypes.putUpAuction
    case .endOfAuction:
      return TKLocales.ActionTypes.endAuction
    case .putUpForSale:
      return TKLocales.ActionTypes.sent
    case .domainRenew:
      return TKLocales.ActionTypes.domainRenew
    case .unknown:
      return TKLocales.ActionTypes.unknown
    }
  }
}

struct TonConnectConfirmationAccountEventActionContentProvider: AccountEventActionContentProvider {
  func title(actionType: AccountEventModel.Action.ActionType) -> String? {
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
      return TKLocales.ActionTypes.unstakeRequest
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
      return TKLocales.ActionTypes.walletInitialize
    case .contractExec:
      return TKLocales.ActionTypes.contractExec
    case .nftCollectionCreation:
      return TKLocales.ActionTypes.nftCollectionDeploy
    case .nftCreation:
      return TKLocales.ActionTypes.nftDeploy
    case .removalFromSale:
      return TKLocales.ActionTypes.nftSaleRemoval
    case .nftPurchase:
      return TKLocales.ActionTypes.nftPurchase
    case .bid:
      return TKLocales.ActionTypes.bid
    case .putUpForAuction:
      return TKLocales.ActionTypes.putUpAuction
    case .endOfAuction:
      return TKLocales.ActionTypes.endAuction
    case .putUpForSale:
      return TKLocales.ActionTypes.sent
    case .domainRenew:
      return TKLocales.ActionTypes.domainRenew
    case .unknown:
      return TKLocales.ActionTypes.unknown
    }
  }
}
