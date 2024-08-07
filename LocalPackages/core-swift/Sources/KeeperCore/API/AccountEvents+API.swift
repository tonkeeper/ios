import Foundation
import TonAPI
import TonSwift
import BigInt

extension AccountEvent {
  init(accountEvent: Components.Schemas.AccountEvent) throws {
    self.eventId = accountEvent.event_id
    self.date = Date(timeIntervalSince1970: TimeInterval(accountEvent.timestamp))
    self.account = try WalletAccount(accountAddress: accountEvent.account)
    self.isScam = accountEvent.is_scam
    self.isInProgress = accountEvent.in_progress
    self.fee = accountEvent.extra
    self.actions = accountEvent.actions.compactMap { action -> AccountEventAction? in
      do {
        let actionType: AccountEventAction.ActionType
        if let tonTransfer = action.TonTransfer {
          actionType = .tonTransfer(try .init(tonTransfer: tonTransfer))
        } else if let jettonTransfer = action.JettonTransfer {
          actionType = .jettonTransfer(try .init(jettonTransfer: jettonTransfer))
        } else if let contractDeploy = action.ContractDeploy {
          actionType = .contractDeploy(try .init(contractDeploy: contractDeploy))
        } else if let nftItemTransfer = action.NftItemTransfer {
          actionType = .nftItemTransfer(try .init(nftItemTransfer: nftItemTransfer))
        } else if let subscribe = action.Subscribe {
          actionType = .subscribe(try .init(subscription: subscribe))
        } else if let unsubscribe = action.UnSubscribe {
          actionType = .unsubscribe(try .init(unsubscription: unsubscribe))
        } else if let auctionBid = action.AuctionBid {
          actionType = .auctionBid(try .init(auctionBid: auctionBid))
        } else if let nftPurchase = action.NftPurchase {
          actionType = .nftPurchase(try .init(nftPurchase: nftPurchase))
        } else if let depositStake = action.DepositStake {
          actionType = .depositStake(try .init(depositStake: depositStake))
        } else if let withdrawStake = action.WithdrawStake {
          actionType = .withdrawStake(try .init(withdrawStake: withdrawStake))
        } else if let withdrawStakeRequest = action.WithdrawStakeRequest {
          actionType = .withdrawStakeRequest(try .init(withdrawStakeRequest: withdrawStakeRequest))
        } else if let jettonSwap = action.JettonSwap {
          actionType = .jettonSwap(try .init(jettonSwap: jettonSwap))
        } else if let jettonMint = action.JettonMint {
          actionType = .jettonMint(try .init(jettonMint: jettonMint))
        } else if let jettonBurn = action.JettonBurn {
          actionType = .jettonBurn(try .init(jettonBurn: jettonBurn))
        } else if let smartContractExec = action.SmartContractExec {
          actionType = .smartContractExec(try .init(smartContractExec: smartContractExec))
        } else if let domainRenew = action.DomainRenew {
          actionType = .domainRenew(try .init(domainRenew: domainRenew))
        } else {
          actionType = .unknown
        }
        
        let status = AccountEventStatus(rawValue: action.status.rawValue)
        return AccountEventAction(type: actionType, status: status, preview: try .init(simplePreview: action.simple_preview))
      } catch {
        return nil
      }
    }
  }
}


extension AccountEventAction.SimplePreview {
  init(simplePreview: Components.Schemas.ActionSimplePreview) throws {
    self.name = simplePreview.name
    self.description = simplePreview.description
    self.value = simplePreview.value
    
    var image: URL?
    if let actionImage = simplePreview.action_image {
      image = URL(string: actionImage)
    }
    self.image = image
    
    var valueImage: URL?
    if let valueImageString = simplePreview.value_image {
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
  init(tonTransfer: Components.Schemas.TonTransferAction) throws {
    self.sender = try WalletAccount(accountAddress: tonTransfer.sender)
    self.recipient = try WalletAccount(accountAddress: tonTransfer.recipient)
    self.amount = tonTransfer.amount
    self.comment = tonTransfer.comment
    self.encryptedComment = EncryptedComment(encryptedComment: tonTransfer.encrypted_comment)
  }
}

extension AccountEventAction.JettonTransfer {
  init(jettonTransfer: Components.Schemas.JettonTransferAction) throws {
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
    self.senderAddress = try Address.parse(jettonTransfer.senders_wallet)
    self.recipientAddress = try Address.parse(jettonTransfer.recipients_wallet)
    self.amount = BigUInt(stringLiteral: jettonTransfer.amount)
    self.jettonInfo = try JettonInfo(jettonPreview: jettonTransfer.jetton)
    self.comment = jettonTransfer.comment
    self.encryptedComment = EncryptedComment(encryptedComment: jettonTransfer.encrypted_comment)
  }
}

extension AccountEventAction.ContractDeploy {
  init(contractDeploy: Components.Schemas.ContractDeployAction) throws {
    self.address = try Address.parse(contractDeploy.address)
  }
}

extension AccountEventAction.NFTItemTransfer {
  init(nftItemTransfer: Components.Schemas.NftItemTransferAction) throws {
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
    self.encryptedComment = EncryptedComment(encryptedComment: nftItemTransfer.encrypted_comment)
  }
}

extension AccountEventAction.Subscription {
  init(subscription: Components.Schemas.SubscriptionAction) throws {
    self.subscriber = try WalletAccount(accountAddress: subscription.subscriber)
    self.subscriptionAddress = try Address.parse(subscription.subscription)
    self.beneficiary = try WalletAccount(accountAddress: subscription.beneficiary)
    self.amount = subscription.amount
    self.isInitial = subscription.initial
  }
}

extension AccountEventAction.Unsubscription {
  init(unsubscription: Components.Schemas.UnSubscriptionAction) throws {
    self.subscriber = try WalletAccount(accountAddress: unsubscription.subscriber)
    self.subscriptionAddress = try Address.parse(unsubscription.subscription)
    self.beneficiary = try WalletAccount(accountAddress: unsubscription.beneficiary)
  }
}

extension AccountEventAction.AuctionBid {
  init(auctionBid: Components.Schemas.AuctionBidAction) throws {
    self.auctionType = auctionBid.auction_type
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
  init(nftPurchase: Components.Schemas.NftPurchaseAction) throws {
    self.auctionType = nftPurchase.auction_type
    self.nft = try NFT(nftItem: nftPurchase.nft)
    self.seller = try WalletAccount(accountAddress: nftPurchase.seller)
    self.buyer = try WalletAccount(accountAddress: nftPurchase.buyer)
    self.price = BigUInt(stringLiteral: nftPurchase.amount.value)
  }
}

extension AccountEventAction.DepositStake {
  init(depositStake: Components.Schemas.DepositStakeAction) throws {
    self.amount = depositStake.amount
    self.staker = try WalletAccount(accountAddress: depositStake.staker)
    self.pool = try WalletAccount(accountAddress: depositStake.pool)
  }
}

extension AccountEventAction.WithdrawStake {
  init(withdrawStake: Components.Schemas.WithdrawStakeAction) throws {
    self.amount = withdrawStake.amount
    self.staker = try WalletAccount(accountAddress: withdrawStake.staker)
    self.pool = try WalletAccount(accountAddress: withdrawStake.pool)
  }
}

extension AccountEventAction.WithdrawStakeRequest {
  init(withdrawStakeRequest: Components.Schemas.WithdrawStakeRequestAction) throws {
    self.amount = withdrawStakeRequest.amount
    self.staker = try WalletAccount(accountAddress: withdrawStakeRequest.staker)
    self.pool = try WalletAccount(accountAddress: withdrawStakeRequest.pool)
  }
}

extension AccountEventAction.RecoverStake {
  init(recoverStake: Components.Schemas.ElectionsRecoverStakeAction) throws {
    self.amount = recoverStake.amount
    self.staker = try WalletAccount(accountAddress: recoverStake.staker)
  }
}

extension AccountEventAction.JettonSwap {
  init(jettonSwap: Components.Schemas.JettonSwapAction) throws {
    self.dex = jettonSwap.dex
    self.amountIn = BigUInt(stringLiteral: jettonSwap.amount_in)
    self.amountOut = BigUInt(stringLiteral: jettonSwap.amount_out)
    self.tonIn = jettonSwap.ton_in
    self.tonOut = jettonSwap.ton_out
    self.user = try WalletAccount(accountAddress: jettonSwap.user_wallet)
    self.router = try WalletAccount(accountAddress: jettonSwap.router)
    if let jettonMasterIn = jettonSwap.jetton_master_in {
      self.jettonInfoIn = try JettonInfo(jettonPreview: jettonMasterIn)
    } else {
      self.jettonInfoIn = nil
    }
    if let jettonMasterOut = jettonSwap.jetton_master_out {
      self.jettonInfoOut = try JettonInfo(jettonPreview: jettonMasterOut)
    } else {
      self.jettonInfoOut = nil
    }
  }
}

extension AccountEventAction.JettonMint {
  init(jettonMint: Components.Schemas.JettonMintAction) throws {
    self.recipient = try WalletAccount(accountAddress: jettonMint.recipient)
    self.recipientsWallet = try Address.parse(jettonMint.recipients_wallet)
    self.amount = BigUInt(stringLiteral: jettonMint.amount)
    self.jettonInfo = try JettonInfo(jettonPreview: jettonMint.jetton)
  }
}

extension AccountEventAction.JettonBurn {
  init(jettonBurn: Components.Schemas.JettonBurnAction) throws {
    self.sender = try WalletAccount(accountAddress: jettonBurn.sender)
    self.senderWallet = try Address.parse(jettonBurn.senders_wallet)
    self.amount = BigUInt(stringLiteral: jettonBurn.amount)
    self.jettonInfo = try JettonInfo(jettonPreview: jettonBurn.jetton)
  }
}

extension AccountEventAction.SmartContractExec {
  init(smartContractExec: Components.Schemas.SmartContractAction) throws {
    self.executor = try WalletAccount(accountAddress: smartContractExec.executor)
    self.contract = try WalletAccount(accountAddress: smartContractExec.contract)
    self.tonAttached = smartContractExec.ton_attached
    self.operation = smartContractExec.operation
    self.payload = smartContractExec.payload
  }
}

extension AccountEventAction.DomainRenew {
  init(domainRenew: Components.Schemas.DomainRenewAction) throws {
    self.domain = domainRenew.domain
    self.contractAddress = domainRenew.contract_address
    self.renewer = try WalletAccount(accountAddress: domainRenew.renewer)
  }
}

extension AccountEventAction.Price {
  init(price: Components.Schemas.Price) {
    amount = BigUInt(stringLiteral: price.value)
    tokenName = price.token_name
  }
}

