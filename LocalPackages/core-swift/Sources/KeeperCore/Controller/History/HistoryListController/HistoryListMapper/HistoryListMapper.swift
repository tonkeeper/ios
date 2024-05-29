import Foundation
import BigInt
import TKLocalize
import TonSwift

struct HistoryListMapper {
  private let dateFormatter: DateFormatter
  private let amountFormatter: AmountFormatter
  private let amountMapper: HistoryListEventAmountMapper
  
  init(dateFormatter: DateFormatter,
       amountFormatter: AmountFormatter,
       amountMapper: HistoryListEventAmountMapper) {
    self.dateFormatter = dateFormatter
    self.amountFormatter = amountFormatter
    self.amountMapper = amountMapper
  }
  
  func mapHistoryEvent(_ event: AccountEvent,
                       eventDate: Date,
                       nftsCollection: NFTsCollection,
                       accountEventRightTopDescriptionProvider: AccountEventRightTopDescriptionProvider,
                       isTestnet: Bool) -> HistoryEvent {
    var accountEventRightTopDescriptionProvider = accountEventRightTopDescriptionProvider
    let actions = event.actions.compactMap { action in
      let rightTopDescription = accountEventRightTopDescriptionProvider.rightTopDescription(
        accountEvent: event,
        action: action
      )
      return mapAction(
        action,
        historyEvent: event,
        rightTopDescription: rightTopDescription,
        nftsCollection: nftsCollection,
        isTestnet: isTestnet
      )
    }
    return HistoryEvent(eventId: event.eventId, actions: actions, accountEvent: event, date: eventDate)
  }
  
  func mapEventsSectionDate(_ date: Date) -> String? {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return TKLocales.Dates.today
    } else if calendar.isDateInYesterday(date) {
      return TKLocales.Dates.yesterday
    } else if calendar.isDate(date, equalTo: Date(), toGranularity: .month) {
      dateFormatter.dateFormat = "d MMMM"
    } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
      dateFormatter.dateFormat = "LLLL"
    } else {
      dateFormatter.dateFormat = "LLLL y"
    }
    return dateFormatter.string(from: date).capitalized
  }
}

private extension HistoryListMapper {
  func mapAction(_ action: AccountEventAction,
                 historyEvent: AccountEvent,
                 rightTopDescription: String?,
                 nftsCollection: NFTsCollection,
                 isTestnet: Bool) -> HistoryEvent.Action? {
    
    switch action.type {
    case .tonTransfer(let tonTransfer):
      return mapTonTransferAction(tonTransfer,
                                  historyEvent: historyEvent,
                                  preview: action.preview,
                                  rightTopDescription: rightTopDescription,
                                  status: action.status.rawValue,
                                  isTestnet: isTestnet)
    case .jettonTransfer(let jettonTransfer):
      return mapJettonTransferAction(jettonTransfer,
                                     historyEvent: historyEvent,
                                     preview: action.preview,
                                     rightTopDescription: rightTopDescription,
                                     status: action.status.rawValue,
                                     isTestnet: isTestnet)
    case .jettonMint(let jettonMint):
      return mapJettonMintAction(jettonMint,
                                 historyEvent: historyEvent,
                                 preview: action.preview,
                                 rightTopDescription: rightTopDescription,
                                 status: action.status.rawValue)
    case .jettonBurn(let jettonBurn):
      return mapJettonBurnAction(jettonBurn,
                                 historyEvent: historyEvent,
                                 preview: action.preview,
                                 rightTopDescription: rightTopDescription,
                                 status: action.status.rawValue)
    case .auctionBid(let auctionBid):
      return mapAuctionBidAction(auctionBid,
                                 historyEvent: historyEvent,
                                 preview: action.preview,
                                 rightTopDescription: rightTopDescription,
                                 status: action.status.rawValue,
                                 isTestnet: isTestnet)
    case .nftPurchase(let nftPurchase):
      return mapNFTPurchaseAction(nftPurchase,
                                  historyEvent: historyEvent,
                                  preview: action.preview,
                                  rightTopDescription: rightTopDescription,
                                  status: action.status.rawValue,
                                  isTestnet: isTestnet)
    case .contractDeploy(let contractDeploy):
      return mapContractDeployAction(contractDeploy,
                                     historyEvent: historyEvent,
                                     preview: action.preview,
                                     rightTopDescription: rightTopDescription,
                                     status: action.status.rawValue, 
                                     isTestnet: isTestnet)
    case .smartContractExec(let smartContractExec):
      return mapSmartContractExecAction(smartContractExec,
                                        historyEvent: historyEvent,
                                        preview: action.preview,
                                        rightTopDescription: rightTopDescription,
                                        status: action.status.rawValue,
                                        isTestnet: isTestnet)
    case .nftItemTransfer(let nftItemTransfer):
      return mapItemTransferAction(nftItemTransfer,
                                   historyEvent: historyEvent,
                                   preview: action.preview,
                                   rightTopDescription: rightTopDescription,
                                   status: action.status.rawValue, 
                                   nftsCollection: nftsCollection,
                                   isTestnet: isTestnet)
    case .depositStake(let depositStake):
      return mapDepositStakeAction(depositStake,
                                   historyEvent: historyEvent,
                                   preview: action.preview,
                                   rightTopDescription: rightTopDescription,
                                   status: action.status.rawValue)
    case .withdrawStake(let withdrawStake):
      return mapWithdrawStakeAction(withdrawStake,
                                    historyEvent: historyEvent,
                                    preview: action.preview,
                                    rightTopDescription: rightTopDescription,
                                    status: action.status.rawValue)
    case .withdrawStakeRequest(let withdrawStakeRequest):
      return mapWithdrawStakeRequestAction(withdrawStakeRequest,
                                           historyEvent: historyEvent,
                                           preview: action.preview,
                                           rightTopDescription: rightTopDescription,
                                           status: action.status.rawValue)
    case .jettonSwap(let jettonSwap):
      return mapJettonSwapAction(jettonSwap,
                                 historyEvent: historyEvent,
                                 preview: action.preview,
                                 rightTopDescription: rightTopDescription,
                                 status: action.status.rawValue,
                                 isTestnet: isTestnet)
    case .domainRenew(let domainRenew):
      return mapDomainRenewAction(
        domainRenew,
        historyEvent: historyEvent,
        preview: action.preview,
        rightTopDescription: rightTopDescription,
        status: action.status.rawValue,
        isTestnet: isTestnet)
    case .unknown:
      return mapUnknownAction(rightTopDescription: rightTopDescription)
    default: return nil
    }
  }
  
  func mapTonTransferAction(_ action: AccountEventAction.TonTransfer,
                            historyEvent: AccountEvent,
                            preview: AccountEventAction.SimplePreview,
                            rightTopDescription: String?,
                            status: String?,
                            isTestnet: Bool) -> HistoryEvent.Action {
    let eventType: HistoryEvent.Action.ActionType
    let leftTopDescription: String
    let amountType: HistoryEventActionAmountMapperActionType
    
    if historyEvent.isScam {
      amountType = .income
      eventType = .spam
      leftTopDescription = action.sender.value(isTestnet: isTestnet)
    } else if action.recipient == historyEvent.account {
      amountType = .income
      eventType = .receieved
      leftTopDescription = action.sender.value(isTestnet: isTestnet)
    } else {
      amountType = .outcome
      eventType = .sent
      leftTopDescription = action.recipient.value(isTestnet: isTestnet)
    }
    
    let amount = amountMapper
      .mapAmount(
        amount: BigUInt(integerLiteral: UInt64(action.amount)),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: amountType,
        currency: .TON)
    return HistoryEvent.Action(eventType: eventType,
                               amount: amount,
                               subamount: nil,
                               leftTopDescription: leftTopDescription,
                               leftBottomDescription: nil,
                               rightTopDescription: rightTopDescription,
                               status: status,
                               comment: action.comment,
                               nft: nil)
  }
  
  func mapJettonTransferAction(_ action: AccountEventAction.JettonTransfer,
                               historyEvent: AccountEvent,
                               preview: AccountEventAction.SimplePreview,
                               rightTopDescription: String?,
                               status: String?,
                               isTestnet: Bool) -> HistoryEvent.Action {
    let eventType: HistoryEvent.Action.ActionType
    let leftTopDescription: String?
    let amountType: HistoryEventActionAmountMapperActionType
    if historyEvent.isScam {
      eventType = .spam
      leftTopDescription = action.sender?.value(isTestnet: isTestnet) ?? nil
      amountType = .income
    } else if action.recipient == historyEvent.account {
      eventType = .receieved
      leftTopDescription = action.sender?.value(isTestnet: isTestnet) ?? nil
      amountType = .income
    } else {
      eventType = .sent
      leftTopDescription = action.recipient?.value(isTestnet: isTestnet) ?? nil
      amountType = .outcome
    }
    
    let amount = amountMapper
      .mapAmount(
        amount: action.amount,
        fractionDigits: action.jettonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: amountType,
        symbol: action.jettonInfo.symbol)
    
    return HistoryEvent.Action(eventType: eventType,
                               amount: amount,
                               subamount: nil,
                               leftTopDescription: leftTopDescription,
                               leftBottomDescription: nil,
                               rightTopDescription: rightTopDescription,
                               status: status,
                               comment: action.comment,
                               nft: nil)
  }
  
  func mapJettonMintAction(_ action: AccountEventAction.JettonMint,
                           historyEvent: AccountEvent,
                           preview: AccountEventAction.SimplePreview,
                           rightTopDescription: String?,
                           status: String?) -> HistoryEvent.Action {
    let amount = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .income,
      symbol: action.jettonInfo.symbol)
    
    return HistoryEvent.Action(eventType: .mint,
                               amount: amount,
                               subamount: nil,
                               leftTopDescription: action.jettonInfo.name,
                               leftBottomDescription: nil,
                               rightTopDescription: rightTopDescription,
                               status: status,
                               comment: nil,
                               nft: nil)
  }
  
  func mapJettonBurnAction(_ action: AccountEventAction.JettonBurn,
                           historyEvent: AccountEvent,
                           preview: AccountEventAction.SimplePreview,
                           rightTopDescription: String?,
                           status: String?) -> HistoryEvent.Action {
    let amount = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .outcome,
      symbol: action.jettonInfo.symbol)
    
    return HistoryEvent.Action(eventType: .burn,
                               amount: amount,
                               subamount: nil,
                               leftTopDescription: action.jettonInfo.name,
                               leftBottomDescription: nil,
                               rightTopDescription: rightTopDescription,
                               status: status,
                               comment: nil,
                               nft: nil)
  }
  
  func mapDepositStakeAction(_ action: AccountEventAction.DepositStake,
                             historyEvent: AccountEvent,
                             preview: AccountEventAction.SimplePreview,
                             rightTopDescription: String?,
                             status: String?) -> HistoryEvent.Action {
    let amount = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(action.amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      type: .outcome,
      currency: .TON)
    
    return HistoryEvent.Action(
      eventType: .depositStake,
      amount: amount,
      subamount: nil,
      leftTopDescription: action.pool.name,
      leftBottomDescription: nil,
      rightTopDescription: rightTopDescription,
      status: status,
      comment: nil,
      nft: nil
    )
  }
  
  func mapWithdrawStakeAction(_ action: AccountEventAction.WithdrawStake,
                              historyEvent: AccountEvent,
                              preview: AccountEventAction.SimplePreview,
                              rightTopDescription: String?,
                              status: String?) -> HistoryEvent.Action {
    let amount = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(action.amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .income,
      currency: .TON)
    
    return HistoryEvent.Action(
      eventType: .withdrawStake,
      amount: amount,
      subamount: nil,
      leftTopDescription: action.pool.name,
      leftBottomDescription: nil,
      rightTopDescription: rightTopDescription,
      status: status,
      comment: nil,
      nft: nil
    )
  }
  
  func mapWithdrawStakeRequestAction(_ action: AccountEventAction.WithdrawStakeRequest,
                                     historyEvent: AccountEvent,
                                     preview: AccountEventAction.SimplePreview,
                                     rightTopDescription: String?,
                                     status: String?) -> HistoryEvent.Action {
    let amount = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(action.amount ?? 0)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .none,
      currency: .TON)
    
    return HistoryEvent.Action(eventType: .withdrawStakeRequest,
                               amount: amount,
                               subamount: nil,
                               leftTopDescription: action.pool.name,
                               leftBottomDescription: nil,
                               rightTopDescription: rightTopDescription,
                               status: status,
                               comment: nil,
                               nft: nil)
  }
  
  func mapAuctionBidAction(_ action: AccountEventAction.AuctionBid,
                           historyEvent: AccountEvent,
                           preview: AccountEventAction.SimplePreview,
                           rightTopDescription: String?,
                           status: String?,
                           isTestnet: Bool) -> HistoryEvent.Action {
    var nft: HistoryEvent.Action.NFTModel?
    if let actionNft = action.nft {
      nft = HistoryEvent.Action.NFTModel(
        nft: actionNft,
        name: actionNft.name,
        collectionName: actionNft.collection?.name ?? .singleNFT,
        image: actionNft.preview.size500)
    }
    
    return HistoryEvent.Action(eventType: .bid,
                               amount: preview.value,
                               subamount: nil,
                               leftTopDescription: action.bidder.value(isTestnet: isTestnet),
                               leftBottomDescription: nil,
                               rightTopDescription: rightTopDescription,
                               status: status,
                               comment: nil,
                               nft: nft)
  }
  
  func mapNFTPurchaseAction(_ action: AccountEventAction.NFTPurchase,
                            historyEvent: AccountEvent,
                            preview: AccountEventAction.SimplePreview,
                            rightTopDescription: String?,
                            status: String?,
                            isTestnet: Bool) -> HistoryEvent.Action {
    
    let collectibleViewModel = HistoryEvent.Action.NFTModel(
      nft: action.nft,
      name: action.nft.name,
      collectionName: action.nft.collection?.name ?? .singleNFT,
      image: action.nft.preview.size500
    )
    let amount = amountMapper
      .mapAmount(
        amount: action.price,
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: action.buyer == historyEvent.account ? .outcome : .income,
        currency: .TON
      )
    
    return HistoryEvent.Action(
      eventType: .nftPurchase,
      amount: amount,
      subamount: nil,
      leftTopDescription: action.seller.value(isTestnet: isTestnet),
      leftBottomDescription: nil,
      rightTopDescription: rightTopDescription,
      status: status,
      comment: nil,
      nft: collectibleViewModel
    )
  }
  
  func mapContractDeployAction(_ action: AccountEventAction.ContractDeploy,
                               historyEvent: AccountEvent,
                               preview: AccountEventAction.SimplePreview,
                               rightTopDescription: String?,
                               status: String?,
                               isTestnet: Bool) -> HistoryEvent.Action {
    return HistoryEvent.Action(
      eventType: .walletInitialized,
      amount: "-",
      subamount: nil,
      leftTopDescription: FriendlyAddress(
        address: action.address,
        testOnly: isTestnet,
        bounceable: false
      ).toShort(),
      leftBottomDescription: nil,
      rightTopDescription: rightTopDescription,
      status: status,
      comment: nil,
      nft: nil
    )
  }
  
  func mapSmartContractExecAction(_ action: AccountEventAction.SmartContractExec,
                                  historyEvent: AccountEvent,
                                  preview: AccountEventAction.SimplePreview,
                                  rightTopDescription: String?,
                                  status: String?,
                                  isTestnet: Bool) -> HistoryEvent.Action {
    let amount = amountMapper
      .mapAmount(
        amount: BigUInt(integerLiteral: UInt64(action.tonAttached)),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: action.executor == historyEvent.account ? .outcome : .income,
        currency: .TON
      )
    
    return HistoryEvent.Action(eventType: .contractExec,
                               amount: amount,
                               subamount: nil,
                               leftTopDescription: action.contract.value(isTestnet: isTestnet),
                               leftBottomDescription: nil,
                               rightTopDescription: rightTopDescription,
                               status: status,
                               comment: nil,
                               nft: nil)
  }
  
  func mapItemTransferAction(_ action: AccountEventAction.NFTItemTransfer,
                             historyEvent: AccountEvent,
                             preview: AccountEventAction.SimplePreview,
                             rightTopDescription: String?,
                             status: String?,
                             nftsCollection: NFTsCollection,
                             isTestnet: Bool) -> HistoryEvent.Action {
    let eventType: HistoryEvent.Action.ActionType
    var leftTopDescription: String?
    if let previewAccount = preview.accounts.first {
      leftTopDescription = previewAccount.address.toFriendly(
        testOnly: isTestnet,
        bounceable: !previewAccount.isWallet
      ).toShort()
    }
    if historyEvent.isScam {
      eventType = .spam
    } else if action.sender == historyEvent.account {
      eventType = .sent
    } else {
      eventType = .receieved
    }
    
    var nft: HistoryEvent.Action.NFTModel?
    if let actionNft = nftsCollection.nfts[action.nftAddress] {
      nft = .init(nft: actionNft,
                  name: actionNft.name,
                  collectionName: actionNft.collection?.name ?? .singleNFT,
                  image: actionNft.preview.size500)
    }
    
    return HistoryEvent.Action(eventType: eventType,
                               amount: "NFT",
                               subamount: nil,
                               leftTopDescription: leftTopDescription,
                               leftBottomDescription: nil,
                               rightTopDescription: rightTopDescription,
                               status: status,
                               comment: action.comment,
                               nft: nft)
  }
  
  func mapJettonSwapAction(_ action: AccountEventAction.JettonSwap,
                           historyEvent: AccountEvent,
                           preview: AccountEventAction.SimplePreview,
                           rightTopDescription: String?,
                           status: String?,
                           isTestnet: Bool) -> HistoryEvent.Action {
    
    let outAmount: String? = {
      let amount: BigUInt
      let fractionDigits: Int
      let maximumFractionDigits: Int
      let symbol: String?
      if let tonOut = action.tonOut {
        amount = BigUInt(integerLiteral: UInt64(tonOut))
        fractionDigits = TonInfo.fractionDigits
        maximumFractionDigits = 2
        symbol = TonInfo.symbol
      } else if let jettonInfoOut = action.jettonInfoOut {
        amount = action.amountOut
        fractionDigits = jettonInfoOut.fractionDigits
        maximumFractionDigits = 2
        symbol = jettonInfoOut.symbol
      } else {
        return nil
      }
      
      return amountMapper
        .mapAmount(
          amount: amount,
          fractionDigits: fractionDigits,
          maximumFractionDigits: maximumFractionDigits,
          type: .income,
          symbol: symbol
        )
    }()
    
    let inAmount: String? = {
      let amount: BigUInt
      let fractionDigits: Int
      let maximumFractionDigits: Int
      let symbol: String?
      if let tonIn = action.tonIn {
        amount = BigUInt(integerLiteral: UInt64(tonIn))
        fractionDigits = TonInfo.fractionDigits
        maximumFractionDigits = 2
        symbol = TonInfo.symbol
      } else if let jettonInfoIn = action.jettonInfoIn {
        amount = action.amountIn
        fractionDigits = jettonInfoIn.fractionDigits
        maximumFractionDigits = 2
        symbol = jettonInfoIn.symbol
      } else {
        return nil
      }
      return amountMapper
        .mapAmount(
          amount: amount,
          fractionDigits: fractionDigits,
          maximumFractionDigits: maximumFractionDigits,
          type: .outcome,
          symbol: symbol
        )
    }()
    
    return HistoryEvent.Action(
      eventType: .jettonSwap,
      amount: outAmount,
      subamount: inAmount,
      leftTopDescription: action.user.value(isTestnet: isTestnet),
      leftBottomDescription: nil,
      rightTopDescription: rightTopDescription,
      status: status,
      comment: nil,
      nft: nil
    )
  }
  
  func mapDomainRenewAction(_ action: AccountEventAction.DomainRenew,
                            historyEvent: AccountEvent,
                            preview: AccountEventAction.SimplePreview,
                            rightTopDescription: String?,
                            status: String?,
                            isTestnet: Bool) -> HistoryEvent.Action {
    
    return HistoryEvent.Action(
      eventType: .domainRenew,
      amount: action.domain,
      subamount: nil,
      leftTopDescription: action.renewer.value(isTestnet: isTestnet),
      leftBottomDescription: nil,
      rightTopDescription: rightTopDescription,
      status: status,
      comment: nil,
      description: preview.description,
      nft: nil
    )
  }
  
  func mapUnknownAction(rightTopDescription: String?) -> HistoryEvent.Action {
    return HistoryEvent.Action(
      eventType: .unknown,
      amount: String.Symbol.minus,
      subamount: nil,
      leftTopDescription: "Something happened but we couldn't recognize",
      leftBottomDescription: nil,
      rightTopDescription: rightTopDescription,
      status: nil,
      comment: nil,
      nft: nil
    )
  }
}

private extension WalletAccount {
  func value(isTestnet: Bool) -> String {
    if let name = name { return name }
    let friendlyAddress = FriendlyAddress(
      address: address,
      testOnly: isTestnet,
      bounceable: !isTestnet
    )
    return friendlyAddress.toShort()
  }
}

private extension String {
  static let singleNFT = "Single NFT"
}
