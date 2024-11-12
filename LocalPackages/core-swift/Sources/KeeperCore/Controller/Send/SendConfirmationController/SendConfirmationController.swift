import Foundation
import TonSwift
import BigInt

public final class SendConfirmationController {
  
  public enum Error: Swift.Error {
    case failedToCalculateFee
    case failedToSendTransaction
    case failedToSign
    case indexerOffline
  }
  
  public var didUpdateModel: ((SendConfirmationModel) -> Void)?
  public var didGetError: ((Error) -> Void)?
  public var didGetExternalSign: ((URL) async throws -> Data?)?
  
  public var signHandler: ((TransferData, Wallet) async throws -> String?)?
  
  private var transactionEmulationExtra: Int64 = 0
  
  public  let wallet: Wallet
  private let recipient: Recipient
  private let sendItem: SendItem
  private let comment: String?
  private let sendService: SendService
  private let accountService: AccountService
  private let blockchainService: BlockchainService
  private let balanceStore: BalanceStore
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let amountFormatter: AmountFormatter
  
  init(wallet: Wallet,
       recipient: Recipient,
       sendItem: SendItem,
       comment: String?,
       sendService: SendService,
       accountService: AccountService,
       blockchainService: BlockchainService,
       balanceStore: BalanceStore,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       amountFormatter: AmountFormatter) {
    self.wallet = wallet
    self.recipient = recipient
    self.sendItem = sendItem
    self.comment = comment
    self.sendService = sendService
    self.accountService = accountService
    self.blockchainService = blockchainService
    self.balanceStore = balanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
  }
  
  public func start() async {
    let model = await buildInitialModel()
    await MainActor.run {
      didUpdateModel?(model)
    }
    await emulate()
  }
  
  public func sendTransaction() async throws {
    do {
      let transactionBoc = try await createTransactionBoc()
      try await sendService.sendTransaction(boc: transactionBoc, wallet: wallet)
      NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
    } catch {
      Task { @MainActor in
        didGetError?(.failedToSendTransaction)
      }
      throw error
    }
  }
}

private extension SendConfirmationController {
  func buildInitialModel() async -> SendConfirmationModel {
    return await buildModel(fee: .loading, feeConverted: .value(nil))
  }
  
  func buildEmulatedModel(fee: Int64?) async -> SendConfirmationModel {
    let feeItem: LoadableModelItem<String>
    let feeConverted: LoadableModelItem<String?>
    if let fee = fee {
      let feeFormatted = amountFormatter.formatAmount(
        BigUInt(UInt64(fee)),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: TonInfo.fractionDigits,
        symbol: TonInfo.symbol
      )
      feeItem = .value(feeFormatted)
      let rates = ratesStore.state
      let currency = currencyStore.state
      if let rates = rates.first(where: { $0.currency == currency }) {
        let rateConverter = RateConverter()
        let converted = rateConverter.convert(
          amount: fee,
          amountFractionLength: TonInfo.fractionDigits,
          rate: rates
        )
        let convertedFeeFormatted = amountFormatter.formatAmount(
          converted.amount,
          fractionDigits: converted.fractionLength,
          maximumFractionDigits: 2,
          currency: currency
        )
        feeConverted = .value(convertedFeeFormatted)
      } else {
        feeConverted = .value(nil)
      }
    } else {
      feeItem = .value("?")
      feeConverted = .value(nil)
    }
    
    return await buildModel(fee: feeItem, feeConverted: feeConverted)
  }
  
  func buildModel(fee: LoadableModelItem<String>,
                  feeConverted: LoadableModelItem<String?>) async -> SendConfirmationModel {
    let image: SendConfirmationModel.Image
    let titleType: SendConfirmationModel.TitleType
    let descriptionType: SendConfirmationModel.DescriptionType
    let formattedAmount: String?
    var formattedConvertedAmount: String?
    switch sendItem {
    case .token(let token, let amount):
      switch token {
      case .ton:
        image = .ton
        titleType = .ton
        descriptionType = .ton
        formattedAmount = amountFormatter.formatAmount(
          amount,
          fractionDigits: TonInfo.fractionDigits,
          maximumFractionDigits: TonInfo.fractionDigits,
          symbol: TonInfo.symbol
        )
        let rates = ratesStore.state
        let currency = currencyStore.state
        if let rates = rates.first(where: { $0.currency == currency }) {
          let rateConverter = RateConverter()
          let converted = rateConverter.convert(
            amount: amount,
            amountFractionLength: TonInfo.fractionDigits,
            rate: rates
          )
          formattedConvertedAmount = amountFormatter.formatAmount(
            converted.amount,
            fractionDigits: converted.fractionLength,
            maximumFractionDigits: 2,
            currency: currency
          )
        }
      case .jetton(let jettonItem):
        image = .jetton(jettonItem.jettonInfo.imageURL)
        titleType = .jetton(jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name)
        descriptionType = .jetton
        formattedAmount = amountFormatter.formatAmount(
          amount,
          fractionDigits: jettonItem.jettonInfo.fractionDigits,
          maximumFractionDigits: jettonItem.jettonInfo.fractionDigits,
          symbol: jettonItem.jettonInfo.symbol
        )
//        let rates = ratesStore.getRates(jettons: [jettonItem.jettonInfo])
//        let currency = await currencyStore.getCurrency()
//        if let rates = rates.jettonsRates.first(where: { $0.jettonInfo == jettonItem.jettonInfo })?.rates.first(where: { $0.currency == currency }) {
//          let rateConverter = RateConverter()
//          let converted = rateConverter.convert(
//            amount: amount,
//            amountFractionLength: TonInfo.fractionDigits,
//            rate: rates
//          )
//          formattedConvertedAmount = amountFormatter.formatAmount(
//            converted.amount,
//            fractionDigits: converted.fractionLength,
//            maximumFractionDigits: 2,
//            currency: currency
//          )
//        }
      }
    case .nft(let nft):
      let description = [nft.name, nft.collection?.name].compactMap { $0 }.joined(separator: " · ")
      image = .nft(nft.imageURL)
      titleType = .nft
      descriptionType = .nft(description)
      formattedAmount = nil
      formattedConvertedAmount = nil
    }
  
    return SendConfirmationModel(
      image: image,
      titleType: titleType,
      descriptionType: descriptionType,
      wallet: wallet,
      recipientAddress: recipient.recipientAddress.shortAddressString,
      recipientName: recipient.recipientAddress.name,
      amount: formattedAmount,
      amountConverted: .value(formattedConvertedAmount),
      fee: fee,
      feeConverted: feeConverted,
      comment: comment
    )
  }
  
  func emulate() async {
    async let createTransactionBocTask = createEmulateTransactionBoc()
    
    do {
      let transactionBoc = try await createTransactionBocTask
      let transactionInfo = try await sendService.loadTransactionInfo(
        boc: transactionBoc,
        wallet: wallet
      )
      let sendTransactionModel = try SendTransactionModel(
        accountEvent: transactionInfo.event,
        risk: transactionInfo.risk,
        transaction: transactionInfo.trace.transaction
      )
      transactionEmulationExtra = sendTransactionModel.extra
      let model = await buildEmulatedModel(fee: sendTransactionModel.fee)
      Task { @MainActor in
        didUpdateModel?(model)
      }
    } catch {
      let model = await buildEmulatedModel(fee: nil)
      Task { @MainActor in
        didUpdateModel?(model)
        didGetError?(.failedToCalculateFee)
      }
    }
  }
  
  func createEmulateTransactionBoc() async throws -> String {
    ""
//    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
//    let boc: String
//    switch sendItem {
//    case .nft(let nft):
//      boc = try await createNFTEmulateTransactionBoc(nft: nft)
//    case .token(let token, let amount):
//      boc = try await createTokenTransactionBoc(
//        token: token,
//        amount: amount,
//        timeout: timeout,
//        signClosure: { [wallet] builder in
//          try await builder.externalSign(wallet: wallet) { transfer in
//            try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
//          }
//        }
//      )
//    }
//    return boc
  }
  
  func createTransactionBoc() async throws -> String {
    ""
//    let boc: String
//    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
//    
//    let indexingLatency = try await sendService.getIndexingLatency(wallet: wallet)
//    
//    if indexingLatency > (TonSwift.DEFAULT_TTL - 30) {
//      throw Error.indexerOffline
//    }
//    
//    switch sendItem {
//    case .nft(let nft):
//      boc = try await createNFTTransactionBoc(nft: nft, timeout: timeout)
//    case .token(let token, let amount):
//      boc = try await createTokenTransactionBoc(token: token, amount: amount, timeout: timeout) { transfer in
//        return try await signTransfer(transfer)
//      }
//    }
//    return boc
  }
  
//  func createTokenTransactionBoc(token: Token, amount: BigUInt, timeout: UInt64, signClosure: (TransferMessageBuilder) async throws -> String) async throws -> String {
//    let seqno = try await sendService.loadSeqno(wallet: wallet)
//                
//    switch token {
//    case .ton:
//      let account = try? await accountService.loadAccount(isTestnet: wallet.isTestnet, address: recipient.recipientAddress.address)
//      let shouldForceBounceFalse = ["empty", "uninit", "nonexist"].contains(account?.status)
//      
//      let isMax: Bool
//      if let balance = balanceStore.state[wallet]?.walletBalance {
//        isMax = BigUInt(balance.balance.tonBalance.amount) == amount
//      } else {
//        isMax = false
//      }
//      let transferMessageBuilder = TransferMessageBuilder(
//        transferData: TransferData(transfer: .ton(
//          TransferData.Ton(
//            amount: amount,
//            isMax: isMax,
//            recipient: recipient.recipientAddress.address,
//            isBouncable: shouldForceBounceFalse ? false : recipient.recipientAddress.isBouncable,
//            comment: comment
//          )
//        ), wallet: wallet, seqno: seqno, timeout: timeout
//        ))
//      return try await transferMessageBuilder.createBoc(signClosure: signClosure)
//    case .jetton(let jettonItem):
//      
//      let payload = jettonItem.jettonInfo.hasCustomPayload ? try await sendService.getJettonCustomPayload(wallet: wallet, jetton: jettonItem.jettonInfo.address) : nil
//      
//      let customPayload = payload?.customPayload
//      let stateInit: StateInit? = {
//        guard let stateInit = payload?.stateInit else {
//          return nil
//        }
//        do {
//          return try StateInit.loadFrom(slice: stateInit.beginParse())
//        } catch {
//          return nil
//        }
//      }()
//      
//      let transferMessageBuilder = TransferMessageBuilder(
//        transferData: TransferData(transfer: .jetton(
//          TransferData.Jetton(
//            jettonAddress: jettonItem.walletAddress,
//            amount: amount,
//            recipient: recipient.recipientAddress.address,
//            responseAddress: nil,
//            isBouncable: recipient.recipientAddress.isBouncable,
//            comment: comment,
//            customPayload: customPayload,
//            stateInit: stateInit
//          )
//        ), wallet: wallet, seqno: seqno, timeout: timeout
//      ))
//      return try await transferMessageBuilder.createBoc(signClosure: signClosure)
//    }
//  }
  
  /// Jetton to Jetton swap
  func createSwapTransactionBoc(from: Address, to: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    
    // TODO: Move to new confirmation!
    
    ""
    
//    let seqno = try await sendService.loadSeqno(wallet: wallet)
//    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
//    
//    let fromWalletAddress = try await blockchainService.getWalletAddress(
//      jettonMaster: from.toRaw(),
//      owner: wallet.address.toRaw(),
//      isTestnet: wallet.isTestnet
//    )
//    
//    let toWalletAddress = try await blockchainService.getWalletAddress(
//      jettonMaster: to.toRaw(),
//      owner: STONFI_CONSTANTS.RouterAddress,
//      isTestnet: wallet.isTestnet
//    )
//    
//    return try await SwapMessageBuilder.sendSwap(
//      wallet: wallet,
//      seqno: seqno,
//      minAskAmount: minAskAmount,
//      offerAmount: offerAmount,
//      jettonToWalletAddress: toWalletAddress,
//      jettonFromWalletAddress: fromWalletAddress,
//      forwardAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_JETTON.ForwardGasAmount,
//      attachedAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_JETTON.GasAmount,
//      timeout: timeout,
//      signClosure: signClosure
//    )
  }
  
  /// Jetton to TON swap
  func createSwapTransactionBoc(from: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    
    // TODO: Move to new confirmation!
    
    ""
    
//    let seqno = try await sendService.loadSeqno(wallet: wallet)
//    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
//
//    let fromWalletAddress = try await blockchainService.getWalletAddress(
//      jettonMaster: from.toRaw(),
//      owner: wallet.address.toRaw(),
//      isTestnet: wallet.isTestnet
//    )
//    
//    let toWalletAddress = try await blockchainService.getWalletAddress(
//      jettonMaster: STONFI_CONSTANTS.TONProxyAddress,
//      owner: STONFI_CONSTANTS.RouterAddress,
//      isTestnet: wallet.isTestnet
//    )
//    
//    return try await SwapMessageBuilder.sendSwap(
//      wallet: wallet,
//      seqno: seqno,
//      minAskAmount: minAskAmount,
//      offerAmount: offerAmount,
//      jettonToWalletAddress: toWalletAddress,
//      jettonFromWalletAddress: fromWalletAddress,
//      forwardAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_TON.ForwardGasAmount,
//      attachedAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_TON.GasAmount,
//      timeout: timeout,
//      signClosure: signClosure
//    )
  }
  
  /// TON to Jetton swap
  func createSwapTransactionBoc(to: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    
    // TODO: Move to new confirmation!
    
    ""
    
//    let seqno = try await sendService.loadSeqno(wallet: wallet)
//    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
//    
//    let fromWalletAddress = try await blockchainService.getWalletAddress(
//      jettonMaster: STONFI_CONSTANTS.TONProxyAddress,
//      owner: STONFI_CONSTANTS.RouterAddress,
//      isTestnet: wallet.isTestnet
//    )
//    
//    let toWalletAddress = try await blockchainService.getWalletAddress(
//      jettonMaster: to.toRaw(),
//      owner: STONFI_CONSTANTS.RouterAddress,
//      isTestnet: wallet.isTestnet
//    )
//    
//    return try await SwapMessageBuilder.sendSwap(
//      wallet: wallet, 
//      seqno: seqno,
//      minAskAmount: minAskAmount,
//      offerAmount: offerAmount,
//      jettonToWalletAddress: toWalletAddress,
//      jettonFromWalletAddress: fromWalletAddress,
//      forwardAmount: STONFI_CONSTANTS.SWAP_TON_TO_JETTON.ForwardGasAmount,
//      attachedAmount: STONFI_CONSTANTS.SWAP_TON_TO_JETTON.ForwardGasAmount + offerAmount,
//      timeout: timeout,
//      signClosure: signClosure
//    )
  }
  
  func createNFTEmulateTransactionBoc(nft: NFT) async throws -> String {
    ""
//    let transferAmount = BigUInt(stringLiteral: "10000000000")
//    let seqno = try await sendService.loadSeqno(wallet: wallet)
//    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
//    
//    
//    var commentCell: Cell?
//    if let comment = comment {
//        commentCell = try Builder().store(int: 0, bits: 32).writeSnakeData(Data(comment.utf8)).endCell()
//    }
//    
//    return try await NFTTransferMessageBuilder.sendNFTTransfer(
//        wallet: wallet,
//        seqno: seqno,
//        nftAddress: nft.address,
//        recipientAddress: recipient.recipientAddress.address,
//        transferAmount: transferAmount,
//        timeout: timeout,
//        forwardPayload: commentCell) { transfer in
//            try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
//        }
  }
  
  func createNFTTransactionBoc(nft: NFT, timeout: UInt64) async throws -> String {
    ""
//    let emulationExtra = BigInt(integerLiteral: transactionEmulationExtra)
//    let minimumTransferAmount = BigInt(stringLiteral: "50000000")
//    var transferAmount = emulationExtra + minimumTransferAmount
//    transferAmount = transferAmount < minimumTransferAmount
//    ? minimumTransferAmount
//    : transferAmount
//    let seqno = try await sendService.loadSeqno(wallet: wallet)
//    let indexingLatency = try await sendService.getIndexingLatency(wallet: wallet)
//    
//    if indexingLatency > (TonSwift.DEFAULT_TTL - 30) {
//      throw Error.indexerOffline
//    }
//    
//    var commentCell: Cell?
//    if let comment = comment {
//        commentCell = try Builder().store(int: 0, bits: 32).writeSnakeData(Data(comment.utf8)).endCell()
//    }
//    
//    let transferData = TransferData(
//      transfer: <#T##TransferData.Transfer#>,
//      wallet: <#T##Wallet#>,
//      messageType: <#T##MessageType#>,
//      seqno: <#T##UInt64#>,
//      timeout: <#T##UInt64?#>
//    )
//    
//    return try await TransferMessageBuilder(
//      transferData: TransferData(transfer: .nft(
//        TransferData.NFT(
//          nftAddress: nft.address,
//          recipient: recipient.recipientAddress.address,
//          responseAddress: nil,
//          isBouncable: recipient.recipientAddress.isBouncable,
//          transferAmount: transferAmount.magnitude,
//          forwardPayload: commentCell
//        )
//      ), wallet: wallet, seqno: seqno, timeout: timeout)
//    ).createBoc { transferMessageBuilder in
//      return try await signTransfer(transferMessageBuilder)
//    }
  }
  
  func signTransfer() async throws -> String {
    ""
//    guard let signHandler,
//          let signedData = try await signHandler(transferBuilder, wallet) else { throw Error.failedToSign }
//    return signedData
  }
}

public extension String {
  var percentEncoded: String? {
    let set = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    return (self as NSString).addingPercentEncoding(withAllowedCharacters: set)
  }
}
