import Foundation
import TKLocalize
import BigInt

public final class HistoryEventDetailsController {
  
  public struct Model {
    public struct ListItem {
      public let title: String
      public let topValue: String
      public let topNumberOfLines: Int
      public let isTopValueFullString: Bool
      public let bottomValue: String?
      
      public init(title: String,
                  topValue: String,
                  topNumberOfLines: Int = 1,
                  isTopValueFullString: Bool = false,
                  bottomValue: String? = nil) {
        self.title = title
        self.topValue = topValue
        self.topNumberOfLines = topNumberOfLines
        self.isTopValueFullString = isTopValueFullString
        self.bottomValue = bottomValue
      }
    }
    public enum HeaderImage {
      case image(TokenImage)
      case nft(URL)
      case swap(fromImage: TokenImage, toImage: TokenImage)
    }
    
    public let headerImage: HeaderImage?
    public let title: String?
    public let aboveTitle: String?
    public let date: String?
    public let fiatPrice: String?
    public let nftName: String?
    public let nftCollectionName: String?
    public let status: String?
    
    public let listItems: [ListItem]
    
    init(headerImage: HeaderImage? = nil,
         title: String? = nil,
         aboveTitle: String? = nil,
         date: String? = nil,
         fiatPrice: String? = nil,
         nftName: String? = nil,
         nftCollectionName: String? = nil,
         status: String? = nil,
         listItems: [ListItem] = []) {
      self.headerImage = headerImage
      self.title = title
      self.aboveTitle = aboveTitle
      self.date = date
      self.fiatPrice = fiatPrice
      self.nftName = nftName
      self.nftCollectionName = nftCollectionName
      self.status = status
      self.listItems = listItems
    }
  }
  
  private let event: AccountEventDetailsEvent
  private let amountMapper: AccountEventAmountMapper
  private let tonRatesStore: TonRatesStore
  private let walletsStore: WalletsStore
  private let currencyStore: CurrencyStore
  private let nftService: NFTService
  
  private let rateConverter = RateConverter()
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "d MMM, HH:mm"
    return formatter
  }()
  
  init(event: AccountEventDetailsEvent,
       amountMapper: AccountEventAmountMapper,
       tonRatesStore: TonRatesStore,
       walletsStore: WalletsStore,
       currencyStore: CurrencyStore,
       nftService: NFTService) {
    self.event = event
    self.amountMapper = amountMapper
    self.tonRatesStore = tonRatesStore
    self.walletsStore = walletsStore
    self.currencyStore = currencyStore
    self.nftService = nftService
  }
  
  public var transactionHash: String {
    String(event.accountEvent.eventId.prefix(8))
  }
  
  public var transactionURL: URL {
    URL(string: "https://tonviewer.com/transaction/\(event.accountEvent.eventId)")!
  }
  
  public var model: Model {
    get async {
      await mapModel()
    }
  }
}

private extension HistoryEventDetailsController {
  func mapModel() async -> Model {
    let isTestnet = (try? await walletsStore.getActiveWallet().isTestnet) ?? false
    let eventAction = event.action
    let date = dateFormatter.string(from: event.accountEvent.date)
    let fee = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(abs(event.accountEvent.fee))),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      type: .none,
      currency: .TON)
    let fiatFee = await tonFiatString(amount: BigUInt(abs(event.accountEvent.fee)))
    let feeListItem = Model.ListItem(
      title: .feeLabel,
      topValue: fee,
      bottomValue: fiatFee)
    
    let title: String?
    switch eventAction.type {
    case let .domainRenew(domainRenew):
      return mapDomainRenew(
        activityEvent: event.accountEvent,
        action: domainRenew,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        description: eventAction.preview.description)
    case let .auctionBid(auctionBid):
      return await mapAuctionBid(
        activityEvent: event.accountEvent,
        action: auctionBid,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status)
    case let .contractDeploy(contractDeploy):
      return mapContractDeploy(
        activityEvent: event.accountEvent,
        action: contractDeploy,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status)
    case let .depositStake(depositStake):
      return mapDepositStake(
        activityEvent: event.accountEvent,
        action: depositStake,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .jettonBurn(jettonBurn):
      return await mapJettonBurn(
        activityEvent: event.accountEvent,
        action: jettonBurn,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status)
    case let .jettonMint(jettonMint):
      return await mapJettonMint(
        activityEvent: event.accountEvent,
        action: jettonMint,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .jettonSwap(jettonSwap):
      return mapJettonSwap(
        activityEvent: event.accountEvent,
        action: jettonSwap,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .jettonTransfer(jettonTransfer):
      return await mapJettonTransfer(
        activityEvent: event.accountEvent,
        action: jettonTransfer,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .nftItemTransfer(nftItemTransfer):
      return mapNFTTransfer(
        activityEvent: event.accountEvent,
        nftTransfer: nftItemTransfer,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .nftPurchase(nftPurchase):
      return await mapNFTPurchase(
        activityEvent: event.accountEvent,
        action: nftPurchase,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .smartContractExec(smartContractExec):
      return await mapSmartContractExec(
        activityEvent: event.accountEvent,
        smartContractExec: smartContractExec,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .tonTransfer(tonTransfer):
      return await mapTonTransfer(
        activityEvent: event.accountEvent,
        tonTransfer: tonTransfer,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .withdrawStake(withdrawStake):
      return await mapWithdrawStake(
        activityEvent: event.accountEvent,
        action: withdrawStake,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case let .withdrawStakeRequest(withdrawStakeRequest):
      return mapWithdrawStakeRequest(
        activityEvent: event.accountEvent,
        action: withdrawStakeRequest,
        date: date,
        feeListItem: feeListItem,
        status: eventAction.status,
        isTestnet: isTestnet)
    case .unknown:
      return mapUnknownAction(
        date: date,
        feeListItem: feeListItem
      )
    case .subscribe:
      title = "None"
    case .unsubscribe:
      title = "None"
    }
    
    return Model(title: title, date: nil, fiatPrice: nil, listItems: [])
  }
  
  func mapTonTransfer(activityEvent: AccountEvent,
                      tonTransfer: AccountEventAction.TonTransfer,
                      date: String,
                      feeListItem: Model.ListItem,
                      status: AccountEventStatus,
                      isTestnet: Bool) async -> Model {
    let amountType: AccountEventActionAmountMapperActionType
    let actionType: ActionTypeEnum
    
    let nameTitle: String
    let nameValue: String?
    let addressTitle: String
    let addressValue: String
    
    if activityEvent.isScam {
      amountType = .income
      actionType = .Received
      addressTitle = .senderAddress
      nameTitle = .sender
      nameValue = tonTransfer.sender.name
      addressValue = tonTransfer.sender.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.sender.isWallet)
    } else if tonTransfer.recipient == activityEvent.account {
      amountType = .income
      actionType = .Received
      addressTitle = .senderAddress
      nameTitle = .sender
      nameValue = tonTransfer.sender.name
      addressValue = tonTransfer.sender.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.sender.isWallet)
    } else {
      amountType = .outcome
      actionType = .Sent
      addressTitle = .recipientAddress
      nameTitle = .recipient
      nameValue = tonTransfer.recipient.name
      addressValue = tonTransfer.recipient.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.sender.isWallet)
    }
    
    let fiatPrice = await tonFiatString(amount: BigUInt(tonTransfer.amount))
    
    let title = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(tonTransfer.amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: amountType,
      currency: .TON)
    
    let dateString: String
    switch actionType {
    case .Received: 
      dateString = TKLocales.EventDetails.received_on(date)
    case .Sent:
      dateString = TKLocales.EventDetails.sent_on(date)
    }
    
    var listItems = [Model.ListItem]()
    
    if let nameValue = nameValue {
      listItems.append(Model.ListItem(title: nameTitle, topValue: nameValue, isTopValueFullString: true))
    }
    listItems.append(Model.ListItem(title: addressTitle, topValue: addressValue, isTopValueFullString: true))
    listItems.append(feeListItem)
    if let comment = tonTransfer.comment, !comment.isEmpty {
      listItems.append(Model.ListItem(title: .comment, topValue: comment, topNumberOfLines: 0))
    }
    
    return Model(
      headerImage: .image(.ton),
      title: title,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapNFTTransfer(activityEvent: AccountEvent,
                      nftTransfer: AccountEventAction.NFTItemTransfer,
                      date: String,
                      feeListItem: Model.ListItem,
                      status: AccountEventStatus,
                      isTestnet: Bool) -> Model {
    let actionString: String
    
    let nameTitle: String
    let nameValue: String?
    let addressTitle: String
    let addressValue: String?
    
    if activityEvent.isScam {
      actionString = .received
      addressTitle = .senderAddress
      nameTitle = .sender
      nameValue = nftTransfer.sender?.name
      addressValue = nftTransfer.sender?.address.toString(testOnly: isTestnet, bounceable: !(nftTransfer.sender?.isWallet ?? false))
    } else if nftTransfer.recipient == activityEvent.account {
      actionString = .received
      addressTitle = .senderAddress
      nameTitle = .sender
      nameValue = nftTransfer.sender?.name
      addressValue = nftTransfer.sender?.address.toString(testOnly: isTestnet, bounceable: !(nftTransfer.sender?.isWallet ?? false))
    } else {
      actionString = .sent
      addressTitle = .recipientAddress
      nameTitle = .recipient
      nameValue = nftTransfer.recipient?.name
      addressValue = nftTransfer.recipient?.address.toString(testOnly: isTestnet, bounceable: !(nftTransfer.recipient?.isWallet ?? false))
    }
    let title = "NFT"
    let dateString = "\(actionString) on \(date)"
    
    var listItems = [Model.ListItem]()
    
    if let nameValue = nameValue {
      listItems.append(Model.ListItem(title: nameTitle, topValue: nameValue, isTopValueFullString: true))
    }
    if let addressValue = addressValue {
      listItems.append(Model.ListItem(title: addressTitle, topValue: addressValue, isTopValueFullString: true))
    }
    listItems.append(feeListItem)
    if let comment = nftTransfer.comment, !comment.isEmpty {
      listItems.append(Model.ListItem(title: .comment, topValue: comment, topNumberOfLines: 0))
    }
    
    let nft = try? nftService.getNFT(address: nftTransfer.nftAddress, isTestnet: isTestnet)
    var headerImage: Model.HeaderImage?
    if let nftImageUrl = nft?.imageURL {
      headerImage = .nft(nftImageUrl)
    }
    
    return Model(
      headerImage: headerImage,
      title: title,
      date: dateString,
      nftName: nft?.name,
      nftCollectionName: nft?.collection?.name,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapNFTPurchase(activityEvent: AccountEvent,
                      action: AccountEventAction.NFTPurchase,
                      date: String,
                      feeListItem: Model.ListItem,
                      status: AccountEventStatus,
                      isTestnet: Bool) async -> Model {
    let nftName = action.nft.name
    let nftCollectionName = action.nft.collection?.name
    let fiatPrice = await tonFiatString(amount: action.price)
    let title = amountMapper.mapAmount(
      amount: action.price,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .outcome,
      currency: .TON)
    let dateString = "Purchased on \(date)"
    
    var listItems = [Model.ListItem]()
    
    if let senderName = action.seller.name {
      listItems.append(Model.ListItem(title: .sender, topValue: senderName, isTopValueFullString: true))
    }
    listItems.append(
      Model.ListItem(
        title: .senderAddress,
        topValue: action.seller.address.toString(testOnly: isTestnet, bounceable: !action.seller.isWallet),
        isTopValueFullString: true
      )
    )
    listItems.append(feeListItem)
    
    var headerImage: Model.HeaderImage?
    if let nftImageUrl = action.nft.imageURL {
      headerImage = .nft(nftImageUrl)
    }
    
    return Model(
      headerImage: headerImage,
      title: title,
      date: dateString,
      fiatPrice: fiatPrice,
      nftName: nftName,
      nftCollectionName: nftCollectionName,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapContractDeploy(activityEvent: AccountEvent,
                         action: AccountEventAction.ContractDeploy,
                         date: String,
                         feeListItem: Model.ListItem,
                         status: AccountEventStatus) -> Model {
    let title = "Wallet initialized"
    
    let listItems = [feeListItem]
    
    return Model(
      title: title,
      date: date,
      fiatPrice: nil,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapAuctionBid(activityEvent: AccountEvent,
                     action: AccountEventAction.AuctionBid,
                     date: String,
                     feeListItem: Model.ListItem,
                     status: AccountEventStatus) async -> Model {
    var title: String?
    var fiatPrice: String?
    if action.price.tokenName == "TON" {
      title = amountMapper.mapAmount(
        amount: action.price.amount,
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        type: .outcome,
        currency: .TON)
      fiatPrice = await tonFiatString(amount: action.price.amount)
    }
    let dateString = "Bid on \(date)"
    var listItems = [Model.ListItem]()
    
    if let name = action.nft?.name {
      listItems.append(Model.ListItem(title: "Name", topValue: name))
    }
    if let issuer = action.nft?.collection?.name {
      listItems.append(Model.ListItem(title: "Issuer", topValue: issuer))
    }
    listItems.append(feeListItem)
    
    return Model(
      title: title,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapSmartContractExec(activityEvent: AccountEvent,
                            smartContractExec: AccountEventAction.SmartContractExec,
                            date: String,
                            feeListItem: Model.ListItem,
                            status: AccountEventStatus,
                            isTestnet: Bool) async -> Model {
    let fiatPrice = await tonFiatString(amount: BigUInt(smartContractExec.tonAttached))
    
    let title = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(smartContractExec.tonAttached)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .outcome,
      currency: .TON)
    let dateString = "Called contract on \(date)"
    
    var listItems = [Model.ListItem]()
    listItems.append(Model.ListItem(title: "Address", topValue: smartContractExec.contract.address.toString(testOnly: isTestnet), isTopValueFullString: true))
    listItems.append(Model.ListItem(title: "Operation", topValue: smartContractExec.operation))
    listItems.append(feeListItem)
    if let payload = smartContractExec.payload {
      listItems.append(Model.ListItem(title: "Payload", topValue: payload, topNumberOfLines: 0, isTopValueFullString: false))
    }
    
    return Model(
      title: title,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapJettonSwap(activityEvent: AccountEvent,
                     action: AccountEventAction.JettonSwap,
                     date: String,
                     feeListItem: Model.ListItem,
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
    
    let dateString = "Swapped on \(date)"
    
    var listItems = [Model.ListItem]()
    listItems.append(
      Model.ListItem(
        title: .recipient,
        topValue: action.user.address.toString(
          testOnly: isTestnet,
          bounceable: !action.user.isWallet
        ),
        isTopValueFullString: true
      )
    )
    listItems.append(feeListItem)
    
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
      listItems: listItems
    )
  }
  
  func mapWithdrawStakeRequest(activityEvent: AccountEvent,
                               action: AccountEventAction.WithdrawStakeRequest,
                               date: String,
                               feeListItem: Model.ListItem,
                               status: AccountEventStatus,
                               isTestnet: Bool) -> Model {
    let title = "Unstake Request"
    let dateString = "\(date)"
    
    var listItems = [Model.ListItem]()
    if let senderName = action.pool.name {
      listItems.append(Model.ListItem(title: .sender, topValue: senderName))
    }
    listItems.append(
      Model.ListItem(
        title: .senderAddress,
        topValue: action.pool.address.toString(
          testOnly: isTestnet,
          bounceable: !action.pool.isWallet
        )
      )
    )
    if let amount = action.amount {
      let formattedAmount = amountMapper.mapAmount(
        amount: BigUInt(integerLiteral: UInt64(amount)),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: TonInfo.fractionDigits,
        type: .none,
        currency: .TON)
      listItems.append(Model.ListItem(title: "Unstake amount", topValue: formattedAmount))
    }
    
    listItems.append(feeListItem)
    
    return Model(
      title: title,
      aboveTitle: nil,
      date: dateString,
      fiatPrice: nil,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapWithdrawStake(activityEvent: AccountEvent,
                        action: AccountEventAction.WithdrawStake,
                        date: String,
                        feeListItem: Model.ListItem,
                        status: AccountEventStatus,
                        isTestnet: Bool) async -> Model {
    let title = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(action.amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      type: .income,
      currency: .TON)
    let fiatPrice = await tonFiatString(amount: BigUInt(action.amount))
    
    let dateString = "Unstake on \(date)"
    
    var listItems = [Model.ListItem]()
    if let nameValue = action.pool.name {
      listItems.append(Model.ListItem(title: .sender, topValue: nameValue))
    }
    listItems.append(
      Model.ListItem(title: .senderAddress,
                     topValue: action.pool.address.toString(testOnly: isTestnet,
                                                            bounceable: !action.pool.isWallet),
                     isTopValueFullString: true)
    )
    listItems.append(feeListItem)
    
    return Model(
      title: title,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapDepositStake(activityEvent: AccountEvent,
                       action: AccountEventAction.DepositStake,
                       date: String,
                       feeListItem: Model.ListItem,
                       status: AccountEventStatus,
                       isTestnet: Bool) -> Model {
    let title = amountMapper.mapAmount(
      amount: BigUInt(integerLiteral: UInt64(action.amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      type: .outcome,
      currency: .TON)
    let dateString = "Staked on \(date)"
    
    var listItems = [Model.ListItem]()
    if let senderName = action.pool.name {
      listItems.append(Model.ListItem(title: .recipient, topValue: senderName))
    }
    listItems.append(
      Model.ListItem(title: .recipientAddress,
                     topValue: action.pool.address.toString(testOnly: isTestnet, bounceable: !action.pool.isWallet),
                     isTopValueFullString: true)
    )
    listItems.append(feeListItem)
    
    return Model(
      title: title,
      aboveTitle: nil,
      date: dateString,
      fiatPrice: nil,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapJettonMint(activityEvent: AccountEvent,
                     action: AccountEventAction.JettonMint,
                     date: String,
                     feeListItem: Model.ListItem,
                     status: AccountEventStatus,
                     isTestnet: Bool) async -> Model {
    let title = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: action.jettonInfo.fractionDigits,
      type: .income,
      symbol: action.jettonInfo.symbol)
    let dateString = "\(String.received) on \(date)"
    let fiatPrice = await jettonFiatString(amount: action.amount, jettonInfo: action.jettonInfo)
    var listItems = [Model.ListItem]()
    if let recipientName = action.recipient.name {
      listItems.append(Model.ListItem(title: .recipient, topValue: recipientName))
    }
    listItems.append(
      Model.ListItem(title: .recipientAddress,
                     topValue: action.recipient.address.toString(testOnly: isTestnet, bounceable: !action.recipient.isWallet),
                     isTopValueFullString: true)
    )
    listItems.append(feeListItem)
    
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
      listItems: listItems
    )
  }
  
  enum ActionTypeEnum {
    case Sent
    case Received
  }
  
  func mapJettonTransfer(activityEvent: AccountEvent,
                         action: AccountEventAction.JettonTransfer,
                         date: String,
                         feeListItem: Model.ListItem,
                         status: AccountEventStatus,
                         isTestnet: Bool) async -> Model {
    let amountType: AccountEventActionAmountMapperActionType
    let actionType: ActionTypeEnum
    
    let nameTitle: String
    let nameValue: String?
    let addressTitle: String
    let addressValue: String?
    
    if activityEvent.isScam {
      amountType = .income
      actionType = .Received
      addressTitle = .senderAddress
      nameTitle = .sender
      nameValue = action.sender?.name
      addressValue = action.sender?.address.toString(testOnly: isTestnet, bounceable: !(action.sender?.isWallet ?? false))
    } else if action.recipient == activityEvent.account {
      amountType = .income
      actionType = .Received
      addressTitle = .senderAddress
      nameTitle = .sender
      nameValue = action.sender?.name
      addressValue = action.sender?.address.toString(testOnly: isTestnet, bounceable: !(action.sender?.isWallet ?? false))
    } else {
      amountType = .outcome
      actionType = .Sent
      addressTitle = .recipientAddress
      nameTitle = .recipient
      nameValue = action.recipient?.name
      addressValue = action.recipient?.address.toString(testOnly: isTestnet, bounceable: !(action.recipient?.isWallet ?? false))
    }
    
    let fiatPrice = await jettonFiatString(amount: action.amount, jettonInfo: action.jettonInfo)
    
    let title = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: action.jettonInfo.fractionDigits,
      type: amountType,
      symbol: action.jettonInfo.symbol)
    
    let dateString: String

    switch actionType {
    case .Received:
      dateString = TKLocales.EventDetails.received_on(date)
    case .Sent:
      dateString = TKLocales.EventDetails.sent_on(date)
    }
    
    var listItems = [Model.ListItem]()
    
    if let nameValue = nameValue {
      listItems.append(Model.ListItem(title: nameTitle, topValue: nameValue, isTopValueFullString: true))
    }
    if let addressValue = addressValue {
      listItems.append(Model.ListItem(title: addressTitle, topValue: addressValue, isTopValueFullString: true))
    }
    listItems.append(feeListItem)
    if let comment = action.comment, !comment.isEmpty {
      listItems.append(Model.ListItem(title: .comment, topValue: comment, topNumberOfLines: 0))
    }
    
    var headerImage: Model.HeaderImage?
    if let imageUrl = action.jettonInfo.imageURL {
      headerImage = .image(.url(imageUrl))
    }
    
    return Model(
      headerImage: headerImage,
      title: title,
      date: dateString,
      fiatPrice: fiatPrice,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapJettonBurn(activityEvent: AccountEvent,
                     action: AccountEventAction.JettonBurn,
                     date: String,
                     feeListItem: Model.ListItem,
                     status: AccountEventStatus) async -> Model {
    let title = amountMapper.mapAmount(
      amount: action.amount,
      fractionDigits: action.jettonInfo.fractionDigits,
      maximumFractionDigits: action.jettonInfo.fractionDigits,
      type: .outcome,
      symbol: action.jettonInfo.symbol)
    let dateString = "Burned on \(date)"
    let fiatPrice = await jettonFiatString(amount: action.amount, jettonInfo: action.jettonInfo)
    let listItems = [feeListItem]
    
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
      listItems: listItems
    )
  }
  
  func mapDomainRenew(activityEvent: AccountEvent,
                      action: AccountEventAction.DomainRenew,
                      date: String,
                      feeListItem: Model.ListItem,
                      status: AccountEventStatus,
                      description: String) -> Model {
    let title = action.domain
    let dateString = "Renewed on \(date)"
    var listItems = [Model.ListItem]()
    listItems.append(Model.ListItem(title: "Operation", topValue: "Domain Renew"))
    if !description.isEmpty {
      listItems.append(Model.ListItem(title: "Description", topValue: description, topNumberOfLines: 0))
    }
    listItems.append(feeListItem)
    return Model(
      title: title,
      date: dateString,
      status: status.rawValue,
      listItems: listItems
    )
  }
  
  func mapUnknownAction(date: String, feeListItem: Model.ListItem) -> Model {
    let title = "Unknown"
    var listItems = [Model.ListItem]()
    listItems.append(Model.ListItem(title: "Operation", topValue: "Unknown"))
    listItems.append(Model.ListItem(
      title: "Description",
      topValue: "Something happened but we don't understand what.",
      topNumberOfLines: 0,
      isTopValueFullString: false))
    listItems.append(feeListItem)
    return Model(
      title: title,
      date: date,
      status: nil,
      listItems: listItems
    )
  }
  
  func tonFiatString(amount: BigUInt) async -> String? {
    let currency = await currencyStore.getCurrency()
    guard let tonRate = await tonRatesStore.getState().first(where: { $0.currency == currency }) else {
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
  
  func jettonFiatString(amount: BigUInt, jettonInfo: JettonInfo) async -> String? {
    return nil
  }
}

private extension String {
  static let feeLabel = TKLocales.EventDetails.fee
  static let received = TKLocales.EventDetails.received
  static let sent = TKLocales.EventDetails.sent
  static let sender = TKLocales.EventDetails.sender
  static let recipient = TKLocales.EventDetails.recipient
  static let senderAddress = TKLocales.EventDetails.sender_address
  static let recipientAddress = TKLocales.EventDetails.recipient_address
  static let comment = TKLocales.EventDetails.comment
}
