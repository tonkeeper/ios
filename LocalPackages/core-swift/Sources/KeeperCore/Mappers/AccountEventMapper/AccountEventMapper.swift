import Foundation
import BigInt
import TKLocalize
import TonSwift

public struct AccountEventMapper {

  private let dateFormatter: DateFormatter
  private let amountFormatter: AmountFormatter
  private let amountMapper: AccountEventAmountMapper

  init(dateFormatter: DateFormatter,
       amountFormatter: AmountFormatter,
       amountMapper: AccountEventAmountMapper) {
    self.dateFormatter = dateFormatter
    self.amountFormatter = amountFormatter
    self.amountMapper = amountMapper
  }
  
  public func mapEvent(_ event: AccountEvent,
                       nftManagmentStore: WalletNFTsManagementStore,
                       eventDate: Date,
                       accountEventRightTopDescriptionProvider: AccountEventRightTopDescriptionProvider,
                       isTestnet: Bool,
                       nftProvider: (Address) -> NFT?,
                       decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?) -> AccountEventModel {
    var accountEventRightTopDescriptionProvider = accountEventRightTopDescriptionProvider
    let actions = event.actions.compactMap { action in
      let rightTopDescription = accountEventRightTopDescriptionProvider.rightTopDescription(
        accountEvent: event,
        action: action
      )
      return mapAction(
        action,
        nftManagmentStore: nftManagmentStore,
        accountEvent: event,
        rightTopDescription: rightTopDescription,
        isTestnet: isTestnet,
        nftProvider: nftProvider,
        decryptedCommentProvider: decryptedCommentProvider
      )
    }
    return AccountEventModel(
      eventId: event.eventId,
      actions: actions,
      accountEvent: event,
      date: eventDate
    )
  }
}

private extension AccountEventMapper {
  func mapAction(_ action: AccountEventAction,
                 nftManagmentStore: WalletNFTsManagementStore,
                 accountEvent: AccountEvent,
                 rightTopDescription: String?,
                 isTestnet: Bool,
                 nftProvider: (Address) -> NFT?,
                 decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?) -> AccountEventModel.Action? {
    
    switch action.type {
    case .tonTransfer(let tonTransfer):
      return mapTonTransferAction(tonTransfer,
                                  accountEvent: accountEvent,
                                  preview: action.preview,
                                  rightTopDescription: rightTopDescription,
                                  status: action.status.rawValue,
                                  isTestnet: isTestnet,
                                  decryptedCommentProvider: decryptedCommentProvider)
    case .jettonTransfer(let jettonTransfer):
      return mapJettonTransferAction(jettonTransfer,
                                     accountEvent: accountEvent,
                                     preview: action.preview,
                                     rightTopDescription: rightTopDescription,
                                     status: action.status.rawValue,
                                     isTestnet: isTestnet,
                                     decryptedCommentProvider: decryptedCommentProvider)
    case .jettonMint(let jettonMint):
      return mapJettonMintAction(jettonMint,
                                 accountEvent: accountEvent,
                                 preview: action.preview,
                                 rightTopDescription: rightTopDescription,
                                 status: action.status.rawValue)
    case .jettonBurn(let jettonBurn):
      return mapJettonBurnAction(jettonBurn,
                                 accountEvent: accountEvent,
                                 preview: action.preview,
                                 rightTopDescription: rightTopDescription,
                                 status: action.status.rawValue)
    case .auctionBid(let auctionBid):
      return mapAuctionBidAction(auctionBid,
                                 nftManagmentStore: nftManagmentStore,
                                 accountEvent: accountEvent,
                                 preview: action.preview,
                                 rightTopDescription: rightTopDescription,
                                 status: action.status.rawValue,
                                 isTestnet: isTestnet)
    case .nftPurchase(let nftPurchase):
      return mapNFTPurchaseAction(nftPurchase,
                                  nftManagmentStore: nftManagmentStore,
                                  accountEvent: accountEvent,
                                  preview: action.preview,
                                  rightTopDescription: rightTopDescription,
                                  status: action.status.rawValue,
                                  isTestnet: isTestnet)
    case .contractDeploy(let contractDeploy):
      return mapContractDeployAction(contractDeploy,
                                     accountEvent: accountEvent,
                                     preview: action.preview,
                                     rightTopDescription: rightTopDescription,
                                     status: action.status.rawValue,
                                     isTestnet: isTestnet)
    case .smartContractExec(let smartContractExec):
      return mapSmartContractExecAction(smartContractExec,
                                        accountEvent: accountEvent,
                                        preview: action.preview,
                                        rightTopDescription: rightTopDescription,
                                        status: action.status.rawValue,
                                        isTestnet: isTestnet)
    case .nftItemTransfer(let nftItemTransfer):
      return mapItemTransferAction(nftItemTransfer,
                                   nftManagmentStore: nftManagmentStore,
                                   accountEvent: accountEvent,
                                   preview: action.preview,
                                   rightTopDescription: rightTopDescription,
                                   status: action.status.rawValue,
                                   isTestnet: isTestnet,
                                   nftProvider: nftProvider,
                                   decryptedCommentProvider: decryptedCommentProvider)
    case .depositStake(let depositStake):
      return mapDepositStakeAction(depositStake,
                                   accountEvent: accountEvent,
                                   preview: action.preview,
                                   rightTopDescription: rightTopDescription,
                                   status: action.status.rawValue)
    case .withdrawStake(let withdrawStake):
      return mapWithdrawStakeAction(withdrawStake,
                                    accountEvent: accountEvent,
                                    preview: action.preview,
                                    rightTopDescription: rightTopDescription,
                                    status: action.status.rawValue)
    case .withdrawStakeRequest(let withdrawStakeRequest):
      return mapWithdrawStakeRequestAction(withdrawStakeRequest,
                                           accountEvent: accountEvent,
                                           preview: action.preview,
                                           rightTopDescription: rightTopDescription,
                                           status: action.status.rawValue)
    case .jettonSwap(let jettonSwap):
      return mapJettonSwapAction(jettonSwap,
                                 accountEvent: accountEvent,
                                 preview: action.preview,
                                 rightTopDescription: rightTopDescription,
                                 status: action.status.rawValue,
                                 isTestnet: isTestnet)
    case .domainRenew(let domainRenew):
      return mapDomainRenewAction(
        domainRenew,
        accountEvent: accountEvent,
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
                            accountEvent: AccountEvent,
                            preview: AccountEventAction.SimplePreview,
                            rightTopDescription: String?,
                            status: String?,
                            isTestnet: Bool,
                            decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?) -> AccountEventModel.Action {
    let eventType: AccountEventModel.Action.ActionType
    let leftTopDescription: String
    let amountType: AccountEventActionAmountMapperActionType
    
    if accountEvent.isScam {
      amountType = .income
      eventType = .spam
      leftTopDescription = action.sender.value(isTestnet: isTestnet)
    } else if action.sender == accountEvent.account {
      amountType = .outcome
      eventType = .sent
      leftTopDescription = action.recipient.value(isTestnet: isTestnet)
    } else {
      amountType = .income
      eventType = .receieved
      leftTopDescription = action.sender.value(isTestnet: isTestnet)
    }
    
    let amount = amountMapper
      .mapAmount(
        amount: BigUInt(integerLiteral: UInt64(abs(action.amount))),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: amountType,
        currency: .TON)
    
    var encryptedComment: AccountEventModel.Action.EncryptedComment?
    if let actionEncryptedComment = action.encryptedComment {
      let payload = EncryptedCommentPayload(
        encryptedComment: actionEncryptedComment,
        senderAddress: action.sender.address
      )
      if let decrypted = decryptedCommentProvider(payload) {
        encryptedComment = .decrypted(decrypted)
      } else {
        encryptedComment = .encrypted(payload)
      }
    }

    return AccountEventModel.Action(eventType: eventType,
                                    amount: amount,
                                    subamount: nil,
                                    leftTopDescription: leftTopDescription,
                                    leftBottomDescription: nil,
                                    rightTopDescription: rightTopDescription,
                                    status: status,
                                    comment: action.comment,
                                    encryptedComment: encryptedComment,
                                    nft: nil)
  }
  
  func mapJettonTransferAction(_ action: AccountEventAction.JettonTransfer,
                               accountEvent: AccountEvent,
                               preview: AccountEventAction.SimplePreview,
                               rightTopDescription: String?,
                               status: String?,
                               isTestnet: Bool,
                               decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?) -> AccountEventModel.Action {
    let eventType: AccountEventModel.Action.ActionType
    let leftTopDescription: String?
    let amountType: AccountEventActionAmountMapperActionType
    if accountEvent.isScam {
      eventType = .spam
      leftTopDescription = action.sender?.value(isTestnet: isTestnet) ?? nil
      amountType = .income
    } else if action.sender == accountEvent.account {
      eventType = .sent
      leftTopDescription = action.recipient?.value(isTestnet: isTestnet) ?? nil
      amountType = .outcome
    } else {
      eventType = .receieved
      leftTopDescription = action.sender?.value(isTestnet: isTestnet) ?? nil
      amountType = .income
    }
    
    let amount = amountMapper
      .mapAmount(
        amount: action.amount,
        fractionDigits: action.jettonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: amountType,
        symbol: action.jettonInfo.symbol)
    
    var encryptedComment: AccountEventModel.Action.EncryptedComment?
    if let actionEncryptedComment = action.encryptedComment {
      let payload = EncryptedCommentPayload(
        encryptedComment: actionEncryptedComment,
        senderAddress: action.senderAddress
      )
      if let decrypted = decryptedCommentProvider(payload) {
        encryptedComment = .decrypted(decrypted)
      } else {
        encryptedComment = .encrypted(payload)
      }
    }
    
    return AccountEventModel.Action(eventType: eventType,
                                    amount: amount,
                                    subamount: nil,
                                    leftTopDescription: leftTopDescription,
                                    leftBottomDescription: nil,
                                    rightTopDescription: rightTopDescription,
                                    status: status,
                                    comment: action.comment,
                                    encryptedComment: encryptedComment,
                                    nft: nil)
  }
  
  func mapJettonMintAction(_ action: AccountEventAction.JettonMint,
                           accountEvent: AccountEvent,
                           preview: AccountEventAction.SimplePreview,
                           rightTopDescription: String?,
                           status: String?) -> AccountEventModel.Action {
    let amount = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .income,
      symbol: action.jettonInfo.symbol)
    
    return AccountEventModel.Action(eventType: .mint,
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
                           accountEvent: AccountEvent,
                           preview: AccountEventAction.SimplePreview,
                           rightTopDescription: String?,
                           status: String?) -> AccountEventModel.Action {
    let amount = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .outcome,
      symbol: action.jettonInfo.symbol)
    
    return AccountEventModel.Action(eventType: .burn,
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
                             accountEvent: AccountEvent,
                             preview: AccountEventAction.SimplePreview,
                             rightTopDescription: String?,
                             status: String?) -> AccountEventModel.Action {
    let amount = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(abs(action.amount))),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      type: .outcome,
      currency: .TON)
    
    return AccountEventModel.Action(
      eventType: .depositStake,
      stakingImplementation: action.implementation,
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
                              accountEvent: AccountEvent,
                              preview: AccountEventAction.SimplePreview,
                              rightTopDescription: String?,
                              status: String?) -> AccountEventModel.Action {
    let amount = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(abs(action.amount))),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .income,
      currency: .TON)
    
    return AccountEventModel.Action(
      eventType: .withdrawStake,
      stakingImplementation: action.implementation,
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
                                     accountEvent: AccountEvent,
                                     preview: AccountEventAction.SimplePreview,
                                     rightTopDescription: String?,
                                     status: String?) -> AccountEventModel.Action {
    let amount = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(abs((action.amount ?? 0)))),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .none,
      currency: .TON)
    
    return AccountEventModel.Action(eventType: .withdrawStakeRequest,
                                    stakingImplementation: action.implementation,
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
                           nftManagmentStore: WalletNFTsManagementStore,
                           accountEvent: AccountEvent,
                           preview: AccountEventAction.SimplePreview,
                           rightTopDescription: String?,
                           status: String?,
                           isTestnet: Bool) -> AccountEventModel.Action {
    var nft: AccountEventModel.Action.ActionNFT?
    if let actionNft = action.nft {
      let nftState: NFTsManagementState.NFTState?
      if let collection = actionNft.collection {
        nftState = nftManagmentStore.getState().nftStates[.collection(collection.address)]
      } else {
        nftState = nftManagmentStore.getState().nftStates[.singleItem(actionNft.address)]
      }

      func composeCollectionName() -> String? {
        if let collection = actionNft.collection {
          return (collection.name == nil || collection.name?.isEmpty == true) ? TKLocales.NftDetails.singleNft : collection.name
        } else {
          return TKLocales.NftDetails.singleNft
        }
      }

      let collectionName: String?
      let isSuspecious: Bool
      switch actionNft.trust {
      case .none, .blacklist, .unknown:
        let isManuallyApproved = nftState == .approved
        isSuspecious = nftState != .approved
        collectionName = isManuallyApproved ? composeCollectionName() : TKLocales.NftDetails.unverifiedNft
      case .whitelist, .graylist:
        collectionName = composeCollectionName()
        isSuspecious = false
      }

      let nftModel = AccountEventModel.Action.ActionNFT(
        nft: actionNft,
        isSuspecious: isSuspecious,
        name: actionNft.name,
        collectionName: collectionName,
        image: actionNft.preview.size500)
      nft = nftModel
    }
    
    return AccountEventModel.Action(eventType: .bid,
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
                            nftManagmentStore: WalletNFTsManagementStore,
                            accountEvent: AccountEvent,
                            preview: AccountEventAction.SimplePreview,
                            rightTopDescription: String?,
                            status: String?,
                            isTestnet: Bool) -> AccountEventModel.Action {
    let nftState: NFTsManagementState.NFTState?
    if let collection = action.nft.collection {
      nftState = nftManagmentStore.getState().nftStates[.collection(collection.address)]
    } else {
      nftState = nftManagmentStore.getState().nftStates[.singleItem(action.nft.address)]
    }

    func composeCollectionName() -> String? {
      if let collection = action.nft.collection {
        return (collection.name == nil || collection.name?.isEmpty == true) ? TKLocales.NftDetails.singleNft : collection.name
      } else {
        return TKLocales.NftDetails.singleNft
      }
    }

    let collectionName: String?
    let isSuspecious: Bool
    switch action.nft.trust {
    case .none, .blacklist, .unknown:
      let isManuallyApproved = nftState == .approved
      isSuspecious = nftState != .approved
      collectionName = isManuallyApproved ? composeCollectionName() : TKLocales.NftDetails.unverifiedNft
    case .whitelist, .graylist:
      collectionName = composeCollectionName()
      isSuspecious = false
    }

    let nftModel = AccountEventModel.Action.ActionNFT(
      nft: action.nft,
      isSuspecious: isSuspecious,
      name: action.nft.name,
      collectionName: collectionName,
      image: action.nft.preview.size500
    )
    let amount = amountMapper
      .mapAmount(
        amount: action.price,
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: action.buyer == accountEvent.account ? .outcome : .income,
        currency: .TON
      )
    
    return AccountEventModel.Action(
      eventType: .nftPurchase,
      amount: amount,
      subamount: nil,
      leftTopDescription: action.seller.value(isTestnet: isTestnet),
      leftBottomDescription: nil,
      rightTopDescription: rightTopDescription,
      status: status,
      comment: nil,
      nft: nftModel
    )
  }
  
  func mapContractDeployAction(_ action: AccountEventAction.ContractDeploy,
                               accountEvent: AccountEvent,
                               preview: AccountEventAction.SimplePreview,
                               rightTopDescription: String?,
                               status: String?,
                               isTestnet: Bool) -> AccountEventModel.Action {
    return AccountEventModel.Action(
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
                                  accountEvent: AccountEvent,
                                  preview: AccountEventAction.SimplePreview,
                                  rightTopDescription: String?,
                                  status: String?,
                                  isTestnet: Bool) -> AccountEventModel.Action {
    let amount = amountMapper
      .mapAmount(
        amount: BigUInt(integerLiteral: UInt64(abs(action.tonAttached))),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: action.executor == accountEvent.account ? .outcome : .income,
        currency: .TON
      )
    
    return AccountEventModel.Action(eventType: .contractExec,
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
                             nftManagmentStore: WalletNFTsManagementStore,
                             accountEvent: AccountEvent,
                             preview: AccountEventAction.SimplePreview,
                             rightTopDescription: String?,
                             status: String?,
                             isTestnet: Bool,
                             nftProvider: (Address) -> NFT?,
                             decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?) -> AccountEventModel.Action {
    let eventType: AccountEventModel.Action.ActionType
    var leftTopDescription: String?
    if let previewAccount = preview.accounts.first {
      leftTopDescription = previewAccount.address.toFriendly(
        testOnly: isTestnet,
        bounceable: !previewAccount.isWallet
      ).toShort()
    }
    if accountEvent.isScam {
      eventType = .spam
    } else if action.sender == accountEvent.account {
      eventType = .sent
    } else {
      eventType = .receieved
    }
    
    var actionNFT: AccountEventModel.Action.ActionNFT?
    if let nft = nftProvider(action.nftAddress) {
      let nftState: NFTsManagementState.NFTState?
      if let collection = nft.collection {
        nftState = nftManagmentStore.getState().nftStates[.collection(collection.address)]
      } else {
        nftState = nftManagmentStore.getState().nftStates[.singleItem(nft.address)]
      }

      func composeCollectionName() -> String? {
        if let collection = nft.collection {
          return (collection.name == nil || collection.name?.isEmpty == true) ? TKLocales.NftDetails.singleNft : collection.name
        } else {
          return TKLocales.NftDetails.singleNft
        }
      }

      var collectionName: String?
      let isSuspecious: Bool
      switch nft.trust {
      case .none, .blacklist, .unknown:
        let isManuallyApproved = nftState == .approved
        isSuspecious = nftState != .approved
        collectionName = isManuallyApproved ? composeCollectionName() : TKLocales.NftDetails.unverifiedNft
      case .whitelist, .graylist:
        collectionName = composeCollectionName()
        isSuspecious = false
      }

      let nftModel = AccountEventModel.Action.ActionNFT(
        nft: nft,
        isSuspecious: isSuspecious,
        name: nft.name,
        collectionName: collectionName,
        image: nft.preview.size500)
      actionNFT = nftModel 
    }

    var encryptedComment: AccountEventModel.Action.EncryptedComment?
    if let actionEncryptedComment = action.encryptedComment, let sender = action.sender {
      let payload = EncryptedCommentPayload(
        encryptedComment: actionEncryptedComment,
        senderAddress: sender.address
      )
      if let decrypted = decryptedCommentProvider(payload) {
        encryptedComment = .decrypted(decrypted)
      } else {
        encryptedComment = .encrypted(payload)
      }
    }
    
    return AccountEventModel.Action(eventType: eventType,
                                    amount: "NFT",
                                    subamount: nil,
                                    leftTopDescription: leftTopDescription,
                                    leftBottomDescription: nil,
                                    rightTopDescription: rightTopDescription,
                                    status: status,
                                    comment: action.comment,
                                    encryptedComment: encryptedComment,
                                    nft: actionNFT)
  }
  
  func mapJettonSwapAction(_ action: AccountEventAction.JettonSwap,
                           accountEvent: AccountEvent,
                           preview: AccountEventAction.SimplePreview,
                           rightTopDescription: String?,
                           status: String?,
                           isTestnet: Bool) -> AccountEventModel.Action {
    
    let outAmount: String? = {
      let amount: BigUInt
      let fractionDigits: Int
      let maximumFractionDigits: Int
      let symbol: String?
      if let tonOut = action.tonOut {
        amount = BigUInt(integerLiteral: UInt64(abs(tonOut)))
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
        amount = BigUInt(integerLiteral: UInt64(abs(tonIn)))
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
    
    return AccountEventModel.Action(
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
                            accountEvent: AccountEvent,
                            preview: AccountEventAction.SimplePreview,
                            rightTopDescription: String?,
                            status: String?,
                            isTestnet: Bool) -> AccountEventModel.Action {
    
    return AccountEventModel.Action(
      eventType: .domainRenew,
      amount: action.domain,
      subamount: nil,
      leftTopDescription: preview.accounts.first?.address.toShortString(bounceable: true),
      leftBottomDescription: nil,
      rightTopDescription: rightTopDescription,
      status: status,
      comment: nil,
      description: preview.description,
      nft: nil
    )
  }
  
  func mapUnknownAction(rightTopDescription: String?) -> AccountEventModel.Action {
    return AccountEventModel.Action(
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
