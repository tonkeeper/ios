import Foundation
import TonAPI
import TonSwift
import BigInt

extension AccountEvent {
  init(accountEvent: TonAPI.AccountEvent) throws {
    self.eventId = accountEvent.eventId
    self.date = Date(timeIntervalSince1970: TimeInterval(accountEvent.timestamp))
    self.account = try WalletAccount(accountAddress: accountEvent.account)
    self.isScam = accountEvent.isScam
    self.isInProgress = accountEvent.inProgress
    self.fee = accountEvent.extra
    self.actions = accountEvent.actions.compactMap { action -> AccountEventAction? in
      do {
        let actionType: AccountEventAction.ActionType
        if let tonTransfer = action.tonTransfer {
          actionType = .tonTransfer(try .init(tonTransfer: tonTransfer))
        } else if let jettonTransfer = action.jettonTransfer {
          actionType = .jettonTransfer(try .init(jettonTransfer: jettonTransfer))
        } else if let contractDeploy = action.contractDeploy {
          actionType = .contractDeploy(try .init(contractDeploy: contractDeploy))
        } else if let nftItemTransfer = action.nftItemTransfer {
          actionType = .nftItemTransfer(try .init(nftItemTransfer: nftItemTransfer))
        } else if let subscribe = action.subscribe {
          actionType = .subscribe(try .init(subscription: subscribe))
        } else if let unsubscribe = action.unSubscribe {
          actionType = .unsubscribe(try .init(unsubscription: unsubscribe))
        } else if let auctionBid = action.auctionBid {
          actionType = .auctionBid(try .init(auctionBid: auctionBid))
        } else if let nftPurchase = action.nftPurchase {
          actionType = .nftPurchase(try .init(nftPurchase: nftPurchase))
        } else if let depositStake = action.depositStake {
          actionType = .depositStake(try .init(depositStake: depositStake))
        } else if let withdrawStake = action.withdrawStake {
          actionType = .withdrawStake(try .init(withdrawStake: withdrawStake))
        } else if let withdrawStakeRequest = action.withdrawStakeRequest {
          actionType = .withdrawStakeRequest(try .init(withdrawStakeRequest: withdrawStakeRequest))
        } else if let jettonSwap = action.jettonSwap {
          actionType = .jettonSwap(try .init(jettonSwap: jettonSwap))
        } else if let jettonMint = action.jettonMint {
          actionType = .jettonMint(try .init(jettonMint: jettonMint))
        } else if let jettonBurn = action.jettonBurn {
          actionType = .jettonBurn(try .init(jettonBurn: jettonBurn))
        } else if let smartContractExec = action.smartContractExec {
          actionType = .smartContractExec(try .init(smartContractExec: smartContractExec))
        } else if let domainRenew = action.domainRenew {
          actionType = .domainRenew(try .init(domainRenew: domainRenew))
        } else {
          actionType = .unknown
        }
        
        let status = AccountEventStatus(rawValue: action.status.rawValue)
        return AccountEventAction(type: actionType, status: status, preview: try .init(simplePreview: action.simplePreview))
      } catch {
        return nil
      }
    }
  }
}


extension AccountEventAction.SimplePreview {
  init(simplePreview: TonAPI.ActionSimplePreview) throws {
    self.name = simplePreview.name
    self.description = simplePreview.description
    self.value = simplePreview.value
    
    var image: URL?
    if let actionImage = simplePreview.actionImage {
      image = URL(string: actionImage)
    }
    self.image = image
    
    var valueImage: URL?
    if let valueImageString = simplePreview.valueImage {
      valueImage = URL(string: valueImageString)
    }
    self.valueImage = valueImage
    
    self.accounts = simplePreview.accounts.compactMap { account in
      guard let walletAccount = try? WalletAccount(accountAddress: account) else { return nil }
      return walletAccount
    }
  }
}

extension AccountEventAction.TonTransfer {
  init(tonTransfer: TonAPI.TonTransferAction) throws {
    self.sender = try WalletAccount(accountAddress: tonTransfer.sender)
    self.recipient = try WalletAccount(accountAddress: tonTransfer.recipient)
    self.amount = tonTransfer.amount
    self.comment = tonTransfer.comment
    self.encryptedComment = EncryptedComment(encryptedComment: tonTransfer.encryptedComment)
  }
}

extension AccountEventAction.JettonTransfer {
  init(jettonTransfer: TonAPI.JettonTransferAction) throws {
    var sender: WalletAccount?
    var recipient: WalletAccount?
    if let senderAccountAddress = jettonTransfer.sender {
      sender = try? WalletAccount(accountAddress: senderAccountAddress)
    }
    if let recipientAccountAddress = jettonTransfer.recipient {
      recipient = try? WalletAccount(accountAddress: recipientAccountAddress)
    }
    
    self.sender = sender
    self.recipient = recipient
    self.senderAddress = try Address.parse(jettonTransfer.sendersWallet)
    self.recipientAddress = try Address.parse(jettonTransfer.recipientsWallet)
    self.amount = BigUInt(stringLiteral: jettonTransfer.amount)
    self.jettonInfo = try JettonInfo(jettonPreview: jettonTransfer.jetton)
    self.comment = jettonTransfer.comment
    self.encryptedComment = EncryptedComment(encryptedComment: jettonTransfer.encryptedComment)
  }
}

extension AccountEventAction.ContractDeploy {
  init(contractDeploy: TonAPI.ContractDeployAction) throws {
    self.address = try Address.parse(contractDeploy.address)
  }
}

extension AccountEventAction.NFTItemTransfer {
  init(nftItemTransfer: TonAPI.NftItemTransferAction) throws {
    var sender: WalletAccount?
    var recipient: WalletAccount?
    if let senderAccountAddress = nftItemTransfer.sender {
      sender = try? WalletAccount(accountAddress: senderAccountAddress)
    }
    if let recipientAccountAddress = nftItemTransfer.recipient {
      recipient = try? WalletAccount(accountAddress: recipientAccountAddress)
    }
    
    self.sender = sender
    self.recipient = recipient
    self.nftAddress = try Address.parse(nftItemTransfer.nft)
    self.comment = nftItemTransfer.comment
    self.payload = nftItemTransfer.payload
    self.encryptedComment = EncryptedComment(encryptedComment: nftItemTransfer.encryptedComment)
  }
}

extension AccountEventAction.Subscription {
  init(subscription: TonAPI.SubscriptionAction) throws {
    self.subscriber = try WalletAccount(accountAddress: subscription.subscriber)
    self.subscriptionAddress = try Address.parse(subscription.subscription)
    self.beneficiary = try WalletAccount(accountAddress: subscription.beneficiary)
    self.amount = subscription.amount
    self.isInitial = subscription.initial
  }
}

extension AccountEventAction.Unsubscription {
  init(unsubscription: TonAPI.UnSubscriptionAction) throws {
    self.subscriber = try WalletAccount(accountAddress: unsubscription.subscriber)
    self.subscriptionAddress = try Address.parse(unsubscription.subscription)
    self.beneficiary = try WalletAccount(accountAddress: unsubscription.beneficiary)
  }
}

extension AccountEventAction.AuctionBid {
  init(auctionBid: TonAPI.AuctionBidAction) throws {
    self.auctionType = {
      switch auctionBid.auctionType {
      case .numberPeriodTg, .dnsPeriodTg, .dnsPeriodTon, .getgems:
        return auctionBid.auctionType.rawValue
      case .unknownDefaultOpenApi:
        return "unknown"
      }
    }()
    self.price = AccountEventAction.Price(price: auctionBid.amount)
    self.bidder = try WalletAccount(accountAddress: auctionBid.bidder)
    self.auction = try WalletAccount(accountAddress: auctionBid.auction)
    
    var nft: NFT?
    if let auctionBidNft = auctionBid.nft {
      nft = try NFT(nftItem: auctionBidNft)
    }
    self.nft = nft
  }
}

extension AccountEventAction.NFTPurchase {
  init(nftPurchase: TonAPI.NftPurchaseAction) throws {
    self.auctionType = nftPurchase.auctionType.rawValue
    self.nft = try NFT(nftItem: nftPurchase.nft)
    self.seller = try WalletAccount(accountAddress: nftPurchase.seller)
    self.buyer = try WalletAccount(accountAddress: nftPurchase.buyer)
    self.price = BigUInt(stringLiteral: nftPurchase.amount.value)
  }
}

extension AccountEventAction.DepositStake {
  init(depositStake: TonAPI.DepositStakeAction) throws {
    self.amount = depositStake.amount
    self.staker = try WalletAccount(accountAddress: depositStake.staker)
    self.pool = try WalletAccount(accountAddress: depositStake.pool)
    self.implementation = StakingPoolImplementation(from: depositStake.implementation)
  }
}

extension AccountEventAction.WithdrawStake {
  init(withdrawStake: TonAPI.WithdrawStakeAction) throws {
    self.amount = withdrawStake.amount
    self.staker = try WalletAccount(accountAddress: withdrawStake.staker)
    self.pool = try WalletAccount(accountAddress: withdrawStake.pool)
    self.implementation = StakingPoolImplementation(from: withdrawStake.implementation)
  }
}

extension AccountEventAction.WithdrawStakeRequest {
  init(withdrawStakeRequest: TonAPI.WithdrawStakeRequestAction) throws {
    self.amount = withdrawStakeRequest.amount
    self.staker = try WalletAccount(accountAddress: withdrawStakeRequest.staker)
    self.pool = try WalletAccount(accountAddress: withdrawStakeRequest.pool)
    self.implementation = StakingPoolImplementation(from: withdrawStakeRequest.implementation)
  }
}

extension AccountEventAction.RecoverStake {
  init(recoverStake: TonAPI.ElectionsRecoverStakeAction) throws {
    self.amount = recoverStake.amount
    self.staker = try WalletAccount(accountAddress: recoverStake.staker)
  }
}

extension AccountEventAction.JettonSwap {
  init(jettonSwap: TonAPI.JettonSwapAction) throws {
    self.dex = jettonSwap.dex.rawValue
    self.amountIn = BigUInt(stringLiteral: jettonSwap.amountIn)
    self.amountOut = BigUInt(stringLiteral: jettonSwap.amountOut)
    self.tonIn = jettonSwap.tonIn
    self.tonOut = jettonSwap.tonOut
    self.user = try WalletAccount(accountAddress: jettonSwap.userWallet)
    self.router = try WalletAccount(accountAddress: jettonSwap.router)
    if let jettonMasterIn = jettonSwap.jettonMasterIn {
      self.jettonInfoIn = try JettonInfo(jettonPreview: jettonMasterIn)
    } else {
      self.jettonInfoIn = nil
    }
    if let jettonMasterOut = jettonSwap.jettonMasterOut {
      self.jettonInfoOut = try JettonInfo(jettonPreview: jettonMasterOut)
    } else {
      self.jettonInfoOut = nil
    }
  }
}

extension AccountEventAction.JettonMint {
  init(jettonMint: TonAPI.JettonMintAction) throws {
    self.recipient = try WalletAccount(accountAddress: jettonMint.recipient)
    self.recipientsWallet = try Address.parse(jettonMint.recipientsWallet)
    self.amount = BigUInt(stringLiteral: jettonMint.amount)
    self.jettonInfo = try JettonInfo(jettonPreview: jettonMint.jetton)
  }
}

extension AccountEventAction.JettonBurn {
  init(jettonBurn: TonAPI.JettonBurnAction) throws {
    self.sender = try WalletAccount(accountAddress: jettonBurn.sender)
    self.senderWallet = try Address.parse(jettonBurn.sendersWallet)
    self.amount = BigUInt(stringLiteral: jettonBurn.amount)
    self.jettonInfo = try JettonInfo(jettonPreview: jettonBurn.jetton)
  }
}

extension AccountEventAction.SmartContractExec {
  init(smartContractExec: TonAPI.SmartContractAction) throws {
    self.executor = try WalletAccount(accountAddress: smartContractExec.executor)
    self.contract = try WalletAccount(accountAddress: smartContractExec.contract)
    self.tonAttached = smartContractExec.tonAttached
    self.operation = smartContractExec.operation
    self.payload = smartContractExec.payload
  }
}

extension AccountEventAction.DomainRenew {
  init(domainRenew: TonAPI.DomainRenewAction) throws {
    self.domain = domainRenew.domain
    self.contractAddress = domainRenew.contractAddress
    self.renewer = try WalletAccount(accountAddress: domainRenew.renewer)
  }
}

extension AccountEventAction.Price {
  init(price: TonAPI.Price) {
    amount = BigUInt(stringLiteral: price.value)
    tokenName = price.tokenName
  }
}

