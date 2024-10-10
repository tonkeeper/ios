import Foundation
import TKLocalize
import KeeperCore
import BigInt
import TonSwift

final class HistoryEventDetailsMapper {
  struct Model {
    enum HeaderImage {
      case image(TokenImage)
      case nft(URL)
      case swap(fromImage: TokenImage, toImage: TokenImage)
    }
    
    public struct NFT {
      public let name: String?
      public let collectionName: String?
      public let isVerified: Bool
    }
    
    enum ListItem {
      case recipient(value: String, copyValue: String)
      case recipientAddress(value: String, copyValue: String)
      case sender(value: String, copyValue: String)
      case senderAddress(value: String, copyValue: String)
      case fee(value: String, converted: String?)
      case refund(value: String, converted: String?)
      case comment(String)
      case encryptedComment
      case description(String)
      case operation(String)
      case other(title: String, value: String, copyValue: String?)
    }
    
    let headerImage: HeaderImage?
    let title: String?
    let aboveTitle: String?
    let date: String?
    let fiatPrice: String?
    let nftModel: NFT?
    let status: String?
    let isScam: Bool
    let listItems: [ListItem]
    
    init(headerImage: HeaderImage? = nil,
         title: String? = nil,
         aboveTitle: String? = nil,
         date: String? = nil,
         fiatPrice: String? = nil,
         nftModel: NFT? = nil,
         status: String? = nil,
         isScam: Bool,
         listItems: [ListItem] = []) {
      self.headerImage = headerImage
      self.title = title
      self.aboveTitle = aboveTitle
      self.date = date
      self.fiatPrice = fiatPrice
      self.nftModel = nftModel
      self.status = status
      self.isScam = isScam
      self.listItems = listItems
    }
  }
  
  private let amountMapper: AccountEventAmountMapper
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let nftService: NFTService
  private let isTestnet: Bool
  
  private let rateConverter = RateConverter()
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "d MMM, HH:mm"
    return formatter
  }()
  
  init(amountMapper: AccountEventAmountMapper, 
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       nftService: NFTService,
       isTestnet: Bool) {
    self.amountMapper = amountMapper
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.nftService = nftService
    self.isTestnet = isTestnet
  }
  
  func mapEvent(event: AccountEventDetailsEvent) -> Model {
    let eventAction = event.action
    let date = dateFormatter.string(from: event.accountEvent.date)
    let fee = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(abs(event.accountEvent.fee))),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      type: .none,
      currency: .TON)
    let fiatFee = convertTonToFiatString(amount: BigUInt(abs(event.accountEvent.fee)))
    
    let title: String?
    switch eventAction.type {
    case let .tonTransfer(tonTransfer):
      return mapTonTransfer(
        activityEvent: event.accountEvent,
        tonTransfer: tonTransfer,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .jettonTransfer(jettonTransfer):
      return mapJettonTransfer(
        activityEvent: event.accountEvent,
        action: jettonTransfer,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .nftItemTransfer(nftItemTransfer):
      return mapNFTTransfer(
        activityEvent: event.accountEvent,
        nftTransfer: nftItemTransfer,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .nftPurchase(nftPurchase):
      return mapNFTPurchase(
        activityEvent: event.accountEvent,
        action: nftPurchase,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .domainRenew(domainRenew):
      return mapDomainRenew(
        activityEvent: event.accountEvent,
        action: domainRenew,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        description: eventAction.preview.description)
    case .unknown:
      return mapUnknownAction(
        date: date,
        fee: fee,
        feeConverted: fiatFee
      )
    case let .contractDeploy(contractDeploy):
      return mapContractDeploy(
        activityEvent: event.accountEvent,
        action: contractDeploy,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status)
    case let .jettonBurn(jettonBurn):
      return mapJettonBurn(
        activityEvent: event.accountEvent,
        action: jettonBurn,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status)
    case let .jettonMint(jettonMint):
      return mapJettonMint(
        activityEvent: event.accountEvent,
        action: jettonMint,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .jettonSwap(jettonSwap):
      return mapJettonSwap(
        activityEvent: event.accountEvent,
        action: jettonSwap,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .auctionBid(auctionBid):
      return mapAuctionBid(
        activityEvent: event.accountEvent,
        action: auctionBid,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status)
    case let .depositStake(depositStake):
      return mapDepositStake(
        activityEvent: event.accountEvent,
        action: depositStake,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .smartContractExec(smartContractExec):
      return mapSmartContractExec(
        activityEvent: event.accountEvent,
        smartContractExec: smartContractExec,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .withdrawStake(withdrawStake):
      return mapWithdrawStake(
        activityEvent: event.accountEvent,
        action: withdrawStake,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .withdrawStakeRequest(withdrawStakeRequest):
      return mapWithdrawStakeRequest(
        activityEvent: event.accountEvent,
        action: withdrawStakeRequest,
        date: date,
        fee: fee,
        feeConverted: fiatFee,
        status: eventAction.status,
        isTestnet: isTestnet)
    case .subscribe:
      title = "None"
    case .unsubscribe:
      title = "None"
    }
    
    return Model(title: title, date: nil, fiatPrice: nil, isScam: false, listItems: [])
  }
  
  private enum TransferDirection {
    case send
    case receive
  }
  
  private func mapTonTransfer(activityEvent: AccountEvent,
                              tonTransfer: AccountEventAction.TonTransfer,
                              date: String,
                              fee: String,
                              feeConverted: String?,
                              status: AccountEventStatus,
                              isTestnet: Bool) -> Model {
    let transferDirection: TransferDirection = {
      if tonTransfer.recipient == activityEvent.account {
        return .receive
      } else {
        return .send
      }
    }()
    
    var listItems = [Model.ListItem]()
    let dateFormatted: String
    let amountType: AccountEventActionAmountMapperActionType
    
    switch transferDirection {
    case .send:
      dateFormatted = TKLocales.EventDetails.sentOn(date)
      amountType = .outcome
      if let name = tonTransfer.recipient.name {
        listItems.append(.recipient(value: name, copyValue: name))
      }
      listItems.append(.recipientAddress(
        value: tonTransfer.recipient.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.recipient.isWallet),
        copyValue: tonTransfer.recipient.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.recipient.isWallet))
      )
    case .receive:
      dateFormatted = TKLocales.EventDetails.receivedOn(date)
      amountType = .income
      if let name = tonTransfer.sender.name {
        listItems.append(.sender(value: name, copyValue: name))
      }
      listItems.append(.senderAddress(
        value: tonTransfer.sender.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.sender.isWallet),
        copyValue: tonTransfer.sender.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.sender.isWallet))
      )
    }
    listItems.append(.fee(value: fee, converted: feeConverted))
    if let comment = tonTransfer.comment, !comment.isEmpty, !activityEvent.isScam {
      listItems.append(.comment(comment))
    }
    if let encryptedComment = tonTransfer.encryptedComment {
      listItems.append(.encryptedComment)
    }
    
    let title = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(tonTransfer.amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: amountType,
      currency: .TON)
    
    let fiatPrice = convertTonToFiatString(amount: BigUInt(tonTransfer.amount))
    
    return Model(
      headerImage: .image(.ton),
      title: title,
      date: dateFormatted,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapJettonTransfer(activityEvent: AccountEvent,
                         action: AccountEventAction.JettonTransfer,
                         date: String,
                         fee: String,
                         feeConverted: String?,
                         status: AccountEventStatus,
                         isTestnet: Bool) -> Model {
    let transferDirection: TransferDirection = {
      if action.recipient == activityEvent.account {
        return .receive
      } else {
        return .send
      }
    }()
    
    var listItems = [Model.ListItem]()
    let dateFormatted: String
    let amountType: AccountEventActionAmountMapperActionType
    
    switch transferDirection {
    case .send:
      dateFormatted = TKLocales.EventDetails.sentOn(date)
      amountType = .outcome
      if let recipient = action.recipient {
        if let name = recipient.name {
          listItems.append(.recipient(value: name, copyValue: name))
        }
        listItems.append(.recipientAddress(
          value: recipient.address.toString(testOnly: isTestnet, bounceable: !recipient.isWallet),
          copyValue: recipient.address.toString(testOnly: isTestnet, bounceable: !recipient.isWallet))
        )
      }
    case .receive:
      dateFormatted = TKLocales.EventDetails.receivedOn(date)
      amountType = .income
      if let sender = action.sender {
        if let name = sender.name {
          listItems.append(.sender(value: name, copyValue: name))
        }
        listItems.append(.senderAddress(
          value: sender.address.toString(testOnly: isTestnet, bounceable: !sender.isWallet),
          copyValue: sender.address.toString(testOnly: isTestnet, bounceable: !sender.isWallet))
        )
      }
    }
    listItems.append(.fee(value: fee, converted: feeConverted))
    if let comment = action.comment, !comment.isEmpty, !activityEvent.isScam {
      listItems.append(.comment(comment))
    }
    if let encryptedComment = action.encryptedComment {
      listItems.append(.encryptedComment)
    }
    
    let title = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: action.jettonInfo.fractionDigits,
      type: amountType,
      symbol: action.jettonInfo.symbol)
    
    let fiatPrice = jettonFiatString(amount: action.amount, jettonInfo: action.jettonInfo)
    
    var headerImage: Model.HeaderImage?
    if let imageUrl = action.jettonInfo.imageURL {
      headerImage = .image(.url(imageUrl))
    }
    
    return Model(
      headerImage: headerImage,
      title: title,
      date: dateFormatted,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapNFTTransfer(activityEvent: AccountEvent,
                      nftTransfer: AccountEventAction.NFTItemTransfer,
                      date: String,
                      fee: String,
                      feeConverted: String?,
                      status: AccountEventStatus,
                      isTestnet: Bool) -> Model {
    
    let transferDirection: TransferDirection = {
      if nftTransfer.recipient == activityEvent.account {
        return .receive
      } else {
        return .send
      }
    }()
    
    var listItems = [Model.ListItem]()
    let dateFormatted: String
    
    switch transferDirection {
    case .send:
      dateFormatted = TKLocales.EventDetails.sentOn(date)
      if let recipient = nftTransfer.recipient {
        if let name = recipient.name {
          listItems.append(.recipient(value: name, copyValue: name))
        }
        listItems.append(.recipientAddress(
          value: recipient.address.toString(testOnly: isTestnet, bounceable: !recipient.isWallet),
          copyValue: recipient.address.toString(testOnly: isTestnet, bounceable: !recipient.isWallet))
        )
      }
    case .receive:
      dateFormatted = TKLocales.EventDetails.receivedOn(date)
      if let sender = nftTransfer.sender {
        if let name = sender.name {
          listItems.append(.sender(value: name, copyValue: name))
        }
        listItems.append(.senderAddress(
          value: sender.address.toString(testOnly: isTestnet, bounceable: !sender.isWallet),
          copyValue: sender.address.toString(testOnly: isTestnet, bounceable: !sender.isWallet))
        )
      }
    }
    
    let nft = try? nftService.getNFT(address: nftTransfer.nftAddress, isTestnet: isTestnet)
    guard nft != nil, nft?.trust != .blacklist else {
      return Model(
        title: "NFT",
        date: dateFormatted,
        status: status.rawValue,
        isScam: activityEvent.isScam,
        listItems: [.fee(value: fee, converted: feeConverted)]
      )
    }
    
    listItems.append(.fee(value: fee, converted: feeConverted))
    if let comment = nftTransfer.comment, !comment.isEmpty, !activityEvent.isScam {
      listItems.append(.comment(comment))
    }
    if let encryptedComment = nftTransfer.encryptedComment {
      listItems.append(.encryptedComment)
    }
    
    var headerImage: Model.HeaderImage?
    if let nftImageUrl = nft?.imageURL {
      headerImage = .nft(nftImageUrl)
    }
    let nftModel = Model.NFT(
      name: nft?.name, collectionName: nft?.collection?.name, isVerified: nft?.trust == .whitelist
    )
    
    return Model(
      headerImage: headerImage,
      title: "NFT",
      date: dateFormatted,
      nftModel: nftModel,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapNFTPurchase(activityEvent: AccountEvent,
                      action: AccountEventAction.NFTPurchase,
                      date: String,
                      fee: String,
                      feeConverted: String?,
                      status: AccountEventStatus,
                      isTestnet: Bool) -> Model {
    var listItems = [Model.ListItem]()
    let dateFormatted = TKLocales.EventDetails.purchasedOn(date)
    
    if let sender = action.seller.name {
      listItems.append(.sender(value: sender, copyValue: sender))
    }
    listItems.append(.senderAddress(value: action.seller.address.toString(testOnly: isTestnet, bounceable: !action.seller.isWallet),
                                    copyValue: action.seller.address.toString(testOnly: isTestnet, bounceable: !action.seller.isWallet)))
    
    listItems.append(.fee(value: fee, converted: feeConverted))
    
    var headerImage: Model.HeaderImage?
    if let nftImageUrl = action.nft.imageURL {
      headerImage = .nft(nftImageUrl)
    }
    
    let nftModel = Model.NFT(
      name: action.nft.name,
      collectionName: action.nft.collection?.name,
      isVerified: action.nft.trust == .whitelist
    )
    
    let title = amountMapper.mapAmount(
      amount: action.price,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .outcome,
      currency: .TON)
    
    let fiatPrice = convertTonToFiatString(amount: action.price)
    
    return Model(
      headerImage: headerImage,
      title: title,
      date: dateFormatted,
      fiatPrice: fiatPrice,
      nftModel: nftModel,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapDomainRenew(activityEvent: AccountEvent,
                      action: AccountEventAction.DomainRenew,
                      date: String,
                      fee: String,
                      feeConverted: String?,
                      status: AccountEventStatus,
                      description: String) -> Model {
    let title = action.domain
    let dateFormatted = TKLocales.EventDetails.renewedOn(date)
    
    var listItems: [Model.ListItem] = [
      .operation(TKLocales.EventDetails.domainRenew),
    ]
    if !description.isEmpty {
      listItems.append(.description(description))
    }
    
    listItems.append(.fee(value: fee, converted: feeConverted))
    
    return Model(
      title: title,
      date: dateFormatted,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapJettonBurn(activityEvent: AccountEvent,
                     action: AccountEventAction.JettonBurn,
                     date: String,
                     fee: String,
                     feeConverted: String?,
                     status: AccountEventStatus) -> Model {
    let title = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: action.jettonInfo.fractionDigits,
      type: .outcome,
      symbol: action.jettonInfo.symbol)
    let dateString = "Burned on \(date)"
    let fiatPrice = jettonFiatString(amount: action.amount, jettonInfo: action.jettonInfo)
  
    var headerImage: Model.HeaderImage?
    if let imageUrl = action.jettonInfo.imageURL {
      headerImage = .image(.url(imageUrl))
    }
    
    return Model(
      headerImage: headerImage,
      title: title,
      aboveTitle: nil,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: [.fee(value: fee, converted: feeConverted)]
    )
  }
  
  func mapJettonMint(activityEvent: AccountEvent,
                     action: AccountEventAction.JettonMint,
                     date: String,
                     fee: String,
                     feeConverted: String?,
                     status: AccountEventStatus,
                     isTestnet: Bool) -> Model {
    let title = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: action.jettonInfo.fractionDigits,
      type: .income,
      symbol: action.jettonInfo.symbol)
    let dateString = TKLocales.EventDetails.receivedOn(date)
    let fiatPrice = jettonFiatString(amount: action.amount, jettonInfo: action.jettonInfo)
    var listItems = [Model.ListItem]()
    if let recipient = action.recipient.name {
      listItems.append(.recipient(value: recipient, copyValue: recipient))
    }
    listItems.append(
      .recipientAddress(value: action.recipient.address.toString(testOnly: isTestnet, bounceable: !action.recipient.isWallet),
                        copyValue: action.recipient.address.toString(testOnly: isTestnet, bounceable: !action.recipient.isWallet))
    )
    listItems.append(.fee(value: fee, converted: feeConverted))
    
    var headerImage: Model.HeaderImage?
    if let imageUrl = action.jettonInfo.imageURL {
      headerImage = .image(.url(imageUrl))
    }
    return Model(
      headerImage: headerImage,
      title: title,
      aboveTitle: nil,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapJettonSwap(activityEvent: AccountEvent,
                     action: AccountEventAction.JettonSwap,
                     date: String,
                     fee: String,
                     feeConverted: String?,
                     status: AccountEventStatus,
                     isTestnet: Bool) -> Model {
    let title: String? = {
      let amount: BigUInt
      let fractionDigits: Int
      let maximumFractionDigits: Int
      let symbol: String?
      if let tonOut = action.tonOut {
        amount = BigUInt(integerLiteral: UInt64(tonOut))
        fractionDigits = TonInfo.fractionDigits
        maximumFractionDigits = TonInfo.fractionDigits
        symbol = TonInfo.symbol
      } else if let jettonInfoOut = action.jettonInfoOut {
        amount = action.amountOut
        fractionDigits = jettonInfoOut.fractionDigits
        maximumFractionDigits = jettonInfoOut.fractionDigits
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
    
    let aboveTitle: String? = {
      let amount: BigUInt
      let fractionDigits: Int
      let maximumFractionDigits: Int
      let symbol: String?
      if let tonIn = action.tonIn {
        amount = BigUInt(integerLiteral: UInt64(tonIn))
        fractionDigits = TonInfo.fractionDigits
        maximumFractionDigits = TonInfo.fractionDigits
        symbol = TonInfo.symbol
      } else if let jettonInfoIn = action.jettonInfoIn {
        amount = action.amountIn
        fractionDigits = jettonInfoIn.fractionDigits
        maximumFractionDigits = jettonInfoIn.fractionDigits
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
    
    let dateString = TKLocales.EventDetails.swappedOn(date)
    
    var listItems = [Model.ListItem]()
    listItems.append(
      .recipientAddress(
        value: action.user.address.toString(testOnly: isTestnet, bounceable: !action.user.isWallet),
        copyValue: action.user.address.toString(testOnly: isTestnet, bounceable: !action.user.isWallet)
      )
    )
    listItems.append(.fee(value: fee, converted: feeConverted))
    
    let headerImage: Model.HeaderImage = {
      let fromImage: TokenImage
      if let _ = action.tonIn {
        fromImage = .ton
      } else if let jettonInfoIn = action.jettonInfoIn {
        fromImage = .url(jettonInfoIn.imageURL)
      } else {
        fromImage = .ton
      }
      
      let toImage: TokenImage
      if let _ = action.tonOut {
        toImage = .ton
      } else if let jettonInfoOut = action.jettonInfoOut {
        toImage = .url(jettonInfoOut.imageURL)
      } else {
        toImage = .ton
      }
      
      return .swap(fromImage: fromImage, toImage: toImage)
    }()
    
    return Model(
      headerImage: headerImage,
      title: title,
      aboveTitle: aboveTitle,
      date: dateString,
      fiatPrice: nil,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapAuctionBid(activityEvent: AccountEvent,
                     action: AccountEventAction.AuctionBid,
                     date: String,
                     fee: String,
                     feeConverted: String?,
                     status: AccountEventStatus) -> Model {
    var title: String?
    var fiatPrice: String?
    if action.price.tokenName == "TON" {
      title = amountMapper.mapAmount(
        amount: action.price.amount,
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: .outcome,
        currency: .TON)
      fiatPrice = convertTonToFiatString(amount: action.price.amount)
    }
    let dateString = "Bid on \(date)"
    var listItems = [Model.ListItem]()
    
    if let name = action.nft?.name {
      listItems.append(.other(title: "Name", value: name, copyValue: name))
    }
    if let issuer = action.nft?.collection?.name {
      listItems.append(.other(title: "Issuer", value: issuer, copyValue: issuer))
    }
    listItems.append(.fee(value: fee, converted: feeConverted))
    
    return Model(
      title: title,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapDepositStake(activityEvent: AccountEvent,
                       action: AccountEventAction.DepositStake,
                       date: String,
                       fee: String,
                       feeConverted: String?,
                       status: AccountEventStatus,
                       isTestnet: Bool) -> Model {
    let title = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(action.amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      type: .outcome,
      currency: .TON)
    let dateString = TKLocales.EventDetails.stakedOn(date)
    
    var listItems = [Model.ListItem]()
    if let poolName = action.pool.name {
      listItems.append(.recipient(value: poolName, copyValue: poolName))
    }
    listItems.append(.recipientAddress(
      value: action.pool.address.toString(testOnly: isTestnet, bounceable: !action.pool.isWallet),
      copyValue: action.pool.address.toString(testOnly: isTestnet, bounceable: !action.pool.isWallet))
    )
    listItems.append(.fee(value: fee, converted: feeConverted))
    
    return Model(
      title: title,
      aboveTitle: nil,
      date: dateString,
      fiatPrice: nil,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapSmartContractExec(activityEvent: AccountEvent,
                            smartContractExec: AccountEventAction.SmartContractExec,
                            date: String,
                            fee: String,
                            feeConverted: String?,
                            status: AccountEventStatus,
                            isTestnet: Bool) -> Model {
    let fiatPrice = convertTonToFiatString(amount: BigUInt(smartContractExec.tonAttached))
    
    let title = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(smartContractExec.tonAttached)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .outcome,
      currency: .TON)
    let dateString = TKLocales.EventDetails.calledContractOn(date)
    
    var listItems = [Model.ListItem]()
    listItems.append(.other(
      title: "Address",
      value: smartContractExec.contract.address.toString(testOnly: isTestnet),
      copyValue: smartContractExec.contract.address.toString(testOnly: isTestnet))
    )
    listItems.append(
      .operation(smartContractExec.operation)
    )
    listItems.append(.fee(value: fee, converted: feeConverted))
    if let payload = smartContractExec.payload {
      listItems.append(.other(
        title: TKLocales.EventDetails.payload,
        value: payload,
        copyValue: payload)
      )
    }

    return Model(
      title: title,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapWithdrawStakeRequest(activityEvent: AccountEvent,
                               action: AccountEventAction.WithdrawStakeRequest,
                               date: String,
                               fee: String,
                               feeConverted: String?,
                               status: AccountEventStatus,
                               isTestnet: Bool) -> Model {
    let title = TKLocales.EventDetails.unstakeRequest
    let dateString = "\(date)"
    
    var listItems = [Model.ListItem]()
    if let poolName = action.pool.name {
      listItems.append(.sender(value: poolName, copyValue: poolName))
    }
    listItems.append(.senderAddress(
      value: action.pool.address.toString(
        testOnly: isTestnet,
        bounceable: !action.pool.isWallet
      ),
      copyValue: action.pool.address.toString(
        testOnly: isTestnet,
        bounceable: !action.pool.isWallet
      ))
    )
    if let amount = action.amount {
      let formattedAmount = amountMapper.mapAmount(
        amount: BigUInt(integerLiteral: UInt64(amount)),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: TonInfo.fractionDigits,
        type: .none,
        currency: .TON)
      listItems.append(.other(title: TKLocales.EventDetails.unstakeAmount,
                              value: formattedAmount,
                              copyValue: formattedAmount))
    }
    listItems.append(.fee(value: fee, converted: feeConverted))
    
    return Model(
      title: title,
      aboveTitle: nil,
      date: dateString,
      fiatPrice: nil,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapWithdrawStake(activityEvent: AccountEvent,
                        action: AccountEventAction.WithdrawStake,
                        date: String,
                        fee: String,
                        feeConverted: String?,
                        status: AccountEventStatus,
                        isTestnet: Bool) -> Model {
    let title = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(action.amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .income,
      currency: .TON)
    let fiatPrice = convertTonToFiatString(amount: BigUInt(action.amount))
    
    let dateString = TKLocales.EventDetails.unstakeOn(date)
    
    var listItems = [Model.ListItem]()
    if let poolName = action.pool.name {
      listItems.append(.sender(value: poolName, copyValue: poolName))
    }
    listItems.append(.senderAddress(
      value: action.pool.address.toString(
        testOnly: isTestnet,
        bounceable: !action.pool.isWallet
      ),
      copyValue: action.pool.address.toString(
        testOnly: isTestnet,
        bounceable: !action.pool.isWallet
      ))
    )
    listItems.append(.fee(value: fee, converted: feeConverted))
    
    return Model(
      title: title,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: listItems
    )
  }
  
  func mapContractDeploy(activityEvent: AccountEvent,
                         action: AccountEventAction.ContractDeploy,
                         date: String,
                         fee: String,
                         feeConverted: String?,
                         status: AccountEventStatus) -> Model {
    let title = TKLocales.EventDetails.walletInitialized
    
    return Model(
      title: title,
      date: date,
      fiatPrice: nil,
      status: status.rawValue,
      isScam: activityEvent.isScam,
      listItems: [.fee(value: fee, converted: feeConverted)]
    )
  }
  
  func mapUnknownAction(date: String, 
                        fee: String,
                        feeConverted: String?) -> Model {
    let title = TKLocales.EventDetails.unknown
    let listItems: [Model.ListItem] = [
      .operation(TKLocales.EventDetails.unknown),
      .description(TKLocales.EventDetails.unknownDescription),
      .fee(value: fee, converted: feeConverted)
    ]
    return Model(
      title: title,
      date: date,
      status: nil,
      isScam: false,
      listItems: listItems
    )
  }
  
  private func convertTonToFiatString(amount: BigUInt) -> String? {
    let currency = currencyStore.getState()
    guard let tonRate = tonRatesStore.getState().first(where: { $0.currency == currency }) else {
      return nil
    }
    
    let fiat = rateConverter.convert(
      amount: amount,
      amountFractionLength: TonInfo.fractionDigits,
      rate: tonRate
    )
    return amountMapper.mapAmount(
      amount: fiat.amount,
      fractionDigits: fiat.fractionLength,
      maximumFractionDigits: 2,
      type: .none,
      currency: currency)
  }
  
  private func jettonFiatString(amount: BigUInt, jettonInfo: JettonInfo) -> String? {
    return nil
  }
}
