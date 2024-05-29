import Foundation
import TonSwift
import BigInt

public final class SendConfirmationController {
  
  public enum Error: Swift.Error {
    case failedToCalculateFee
    case failedToSendTransaction
    case failedToSign
  }
  
  public var didUpdateModel: ((SendConfirmationModel) -> Void)?
  public var didGetError: ((Error) -> Void)?
  public var didGetExternalSign: ((URL) async throws -> Data?)?
  
  private var transactionEmulationExtra: Int64 = 0
  
  public  let wallet: Wallet
  private let recipient: Recipient
  private let sendItem: SendItem
  private let comment: String?
  private let sendService: SendService
  private let stonfiService: StonfiService
  private let blockchainService: BlockchainService
  private let balanceStore: BalanceStore
  private let ratesStore: RatesStore
  private let currencyStore: CurrencyStore
  private let mnemonicRepository: WalletMnemonicRepository
  private let amountFormatter: AmountFormatter
  
  init(wallet: Wallet,
       recipient: Recipient,
       sendItem: SendItem,
       comment: String?,
       sendService: SendService,
       stonfiService: StonfiService,
       blockchainService: BlockchainService,
       balanceStore: BalanceStore,
       ratesStore: RatesStore,
       currencyStore: CurrencyStore,
       mnemonicRepository: WalletMnemonicRepository,
       amountFormatter: AmountFormatter) {
    self.wallet = wallet
    self.recipient = recipient
    self.sendItem = sendItem
    self.comment = comment
    self.sendService = sendService
    self.stonfiService = stonfiService
    self.blockchainService = blockchainService
    self.balanceStore = balanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.mnemonicRepository = mnemonicRepository
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
      NotificationCenter.default.post(
        name: NSNotification.Name(rawValue: "DID SEND TRANSACTION"),
        object: nil,
        userInfo: ["Wallet": wallet]
      )
    } catch {
      Task { @MainActor in
        didGetError?(.failedToSendTransaction)
      }
      throw error
    }
  }
  
  public func isNeedToConfirm() -> Bool {
    return wallet.isRegular
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
      let rates = ratesStore.getRates(jettons: [])
      let currency = await currencyStore.getActiveCurrency()
      if let rates = rates.ton.first(where: { $0.currency == currency }) {
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
        let rates = ratesStore.getRates(jettons: [])
        let currency = await currencyStore.getActiveCurrency()
        if let rates = rates.ton.first(where: { $0.currency == currency }) {
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
        let rates = ratesStore.getRates(jettons: [jettonItem.jettonInfo])
        let currency = await currencyStore.getActiveCurrency()
        if let rates = rates.jettonsRates.first(where: { $0.jettonInfo == jettonItem.jettonInfo })?.rates.first(where: { $0.currency == currency }) {
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
      }
    case .nft(let nft):
      let description = [nft.name, nft.collection?.name].compactMap { $0 }.joined(separator: " · ")
      image = .nft(nft.imageURL)
      titleType = .nft
      descriptionType = .nft(description)
      formattedAmount = nil
      formattedConvertedAmount = nil
    case .swap, .staking:
        image = .ton
        titleType = .ton
        descriptionType = .ton
        formattedAmount = nil
        formattedConvertedAmount = nil
    }
    
    return SendConfirmationModel(
      image: image,
      titleType: titleType,
      descriptionType: descriptionType,
      wallet: wallet.model.emojiLabel,
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
      let sendTransactionModel = SendTransactionModel(
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
    let boc: String
    switch sendItem {
    case .nft(let nft):
      boc = try await createNFTEmulateTransactionBoc(nft: nft)
    case .token(let token, let amount):
      boc = try await createTokenTransactionBoc(token: token, amount: amount) { transfer in
        try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
      }
    case .swap(let swapType):
        let signClosure: (WalletTransfer) async throws -> Data = { transfer in
            try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
        }
        switch swapType {
        case let .jettonJetton(from, to, minAskAmount, offerAmount):
            boc = try await createSwapTransactionBoc(from: from, to: to, minAskAmount: minAskAmount, offerAmount: offerAmount, signClosure: signClosure)
        case let .jettonTon(from, minAskAmount, offerAmount):
            boc = try await createSwapTransactionBoc(from: from, minAskAmount: minAskAmount, offerAmount: offerAmount, signClosure: signClosure)
        case let .tonJetton(to, minAskAmount, offerAmount):
            boc = try await createSwapTransactionBoc(to: to, minAskAmount: minAskAmount, offerAmount: offerAmount, signClosure: signClosure)
        }
    case .staking(let pool, let token, let amount):
        boc = try await testBoc(jettonAddress: token, amount: amount, pool: pool) { transfer in
            return try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
        }
    }
    return boc
  }
  
  func createTransactionBoc() async throws -> String {
    let boc: String
    switch sendItem {
    case .nft(let nft):
      boc = try await createNFTTransactionBoc(nft: nft)
    case .token(let token, let amount):
      boc = try await createTokenTransactionBoc(token: token, amount: amount) { transfer in
        return try await signTransfer(transfer)
      }
    case .swap(let swapType):
        func signClosure(transfer: WalletTransfer) async throws -> Data {
            return try await signTransfer(transfer)
        }
        switch swapType {
        case let .jettonJetton(from, to, minAskAmount, offerAmount):
            boc = try await createSwapTransactionBoc(from: from, to: to, minAskAmount: minAskAmount, offerAmount: offerAmount, signClosure: signClosure)
        case let .jettonTon(from, minAskAmount, offerAmount):
            boc = try await createSwapTransactionBoc(from: from, minAskAmount: minAskAmount, offerAmount: offerAmount, signClosure: signClosure)
        case let .tonJetton(to, minAskAmount, offerAmount):
            boc = try await createSwapTransactionBoc(to: to, minAskAmount: minAskAmount, offerAmount: offerAmount, signClosure: signClosure)
        }
    case .staking(let pool, let token, let amount):
        boc = try await testBoc(jettonAddress: token, amount: amount, pool: pool) { transfer in
            return try await signTransfer(transfer)
        }
    }
    return boc
  }
  
  func createTokenTransactionBoc(token: Token, amount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
        
    switch token {
    case .ton:
      let isMax: Bool
      if let balance = try? balanceStore.getBalance(wallet: wallet) {
        isMax = BigUInt(balance.balance.tonBalance.amount) == amount
      } else {
        isMax = false
      }
      return try await TonTransferMessageBuilder.sendTonTransfer(
        wallet: wallet,
        seqno: seqno,
        value: amount,
        isMax: isMax,
        recipientAddress: recipient.recipientAddress.address,
        isBounceable: recipient.recipientAddress.isBouncable,
        comment: comment,
        timeout: timeout,
        signClosure: signClosure
      )
    case .jetton(let jettonItem):
      return try await TokenTransferMessageBuilder.sendTokenTransfer(
        wallet: wallet,
        seqno: seqno,
        tokenAddress: jettonItem.walletAddress,
        value: amount,
        recipientAddress: recipient.recipientAddress.address,
        isBounceable: recipient.recipientAddress.isBouncable,
        comment: comment,
        timeout: timeout,
        signClosure: signClosure
      )
    }
  }
  
  /// Jetton to Jetton swap
  func createSwapTransactionBoc(from: Address, to: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    
    let fromWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: from.toRaw(),
      owner: wallet.address.toRaw(),
      isTestnet: wallet.isTestnet
    )
    
    let toWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: to.toRaw(),
      owner: STONFI_CONSTANTS.RouterAddress,
      isTestnet: wallet.isTestnet
    )
    
    return try await SwapMessageBuilder.sendSwap(
      wallet: wallet,
      seqno: seqno,
      minAskAmount: minAskAmount,
      offerAmount: offerAmount,
      jettonToWalletAddress: toWalletAddress,
      jettonFromWalletAddress: fromWalletAddress,
      forwardAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_JETTON.ForwardGasAmount,
      attachedAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_JETTON.GasAmount,
      timeout: timeout,
      signClosure: signClosure
    )
  }
  
  /// Jetton to TON swap
  func createSwapTransactionBoc(from: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)

    let fromWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: from.toRaw(),
      owner: wallet.address.toRaw(),
      isTestnet: wallet.isTestnet
    )
    
    let toWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: STONFI_CONSTANTS.TONProxyAddress,
      owner: STONFI_CONSTANTS.RouterAddress,
      isTestnet: wallet.isTestnet
    )
    
    return try await SwapMessageBuilder.sendSwap(
      wallet: wallet,
      seqno: seqno,
      minAskAmount: minAskAmount,
      offerAmount: offerAmount,
      jettonToWalletAddress: toWalletAddress,
      jettonFromWalletAddress: fromWalletAddress,
      forwardAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_TON.ForwardGasAmount,
      attachedAmount: STONFI_CONSTANTS.SWAP_JETTON_TO_TON.GasAmount,
      timeout: timeout,
      signClosure: signClosure
    )
  }
  
  /// TON to Jetton swap
  func createSwapTransactionBoc(to: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    
    let fromWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: STONFI_CONSTANTS.TONProxyAddress,
      owner: STONFI_CONSTANTS.RouterAddress,
      isTestnet: wallet.isTestnet
    )
    
    let toWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: to.toRaw(),
      owner: STONFI_CONSTANTS.RouterAddress,
      isTestnet: wallet.isTestnet
    )
    
    return try await SwapMessageBuilder.sendSwap(
      wallet: wallet, 
      seqno: seqno,
      minAskAmount: minAskAmount,
      offerAmount: offerAmount,
      jettonToWalletAddress: toWalletAddress,
      jettonFromWalletAddress: fromWalletAddress,
      forwardAmount: STONFI_CONSTANTS.SWAP_TON_TO_JETTON.ForwardGasAmount,
      attachedAmount: STONFI_CONSTANTS.SWAP_TON_TO_JETTON.ForwardGasAmount + offerAmount,
      timeout: timeout,
      signClosure: signClosure
    )
  }
  
  func createNFTEmulateTransactionBoc(nft: NFT) async throws -> String {
    let transferAmount = BigUInt(stringLiteral: "10000000000")
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    
    
    var commentCell: Cell?
    if let comment = comment {
        commentCell = try Builder().store(int: 0, bits: 32).writeSnakeData(Data(comment.utf8)).endCell()
    }
    
    return try await NFTTransferMessageBuilder.sendNFTTransfer(
        wallet: wallet,
        seqno: seqno,
        nftAddress: nft.address,
        recipientAddress: recipient.recipientAddress.address,
        transferAmount: transferAmount,
        timeout: timeout,
        forwardPayload: commentCell) { transfer in
            try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
        }
  }
  
  func createNFTTransactionBoc(nft: NFT) async throws -> String {
    let emulationExtra = BigInt(integerLiteral: transactionEmulationExtra)
    let minimumTransferAmount = BigInt(stringLiteral: "50000000")
    var transferAmount = emulationExtra + minimumTransferAmount
    transferAmount = transferAmount < minimumTransferAmount
    ? minimumTransferAmount
    : transferAmount
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    
    var commentCell: Cell?
    if let comment = comment {
        commentCell = try Builder().store(int: 0, bits: 32).writeSnakeData(Data(comment.utf8)).endCell()
    }
    
    return try await NFTTransferMessageBuilder.sendNFTTransfer(
        wallet: wallet,
        seqno: seqno,
        nftAddress: nft.address,
        recipientAddress: recipient.recipientAddress.address,
        transferAmount: transferAmount.magnitude,
        timeout: timeout,
        forwardPayload: commentCell
        ) { transfer in
          return try await signTransfer(transfer)
        }
  }
  
  func signTransfer(_ transfer: WalletTransfer) async throws -> Data {
    switch wallet.identity.kind {
    case .Regular:
      let mnemonic = try mnemonicRepository.getMnemonic(forWallet: wallet)
      let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
      let privateKey = keyPair.privateKey
      return try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: privateKey.data))
    case .Lockup:
      throw Error.failedToSign
    case .Watchonly:
      throw Error.failedToSign
    case .External(let publicKey, let walletContractVersion):
      return try await signExternal(
        transfer: transfer.signingMessage.endCell().toBoc(),
        publicKey: publicKey,
        revision: walletContractVersion
      )
    }
  }
  
  func signExternal(transfer: Data, publicKey: TonSwift.PublicKey, revision: WalletContractVersion) async throws -> Data {
    guard let url = createTonSignURL(transfer: transfer, publicKey: publicKey, revision: revision),
          let didGetExternalSign,
          let signedData = try await didGetExternalSign(url) else {
      throw Error.failedToSign
    }
    return signedData
  }
  
  func createTonSignURL(transfer: Data, publicKey: TonSwift.PublicKey, revision: WalletContractVersion) -> URL? {
    guard let publicKey = publicKey.data.base64EncodedString().percentEncoded,
          let body = transfer.base64EncodedString().percentEncoded else { return nil }
    let v = revision.rawValue.lowercased()
    
    let string = "tonsign://?pk=\(publicKey)&body=\(body)&v=\(v)&return=\("tonkeeperx://publish".percentEncoded ?? "")"
    return URL(string: string)
  }
}

private extension SendConfirmationController {
    func testBoc(
        jettonAddress: Address,
        amount: BigUInt,
        pool: PoolInfo,
        signClosure: (WalletTransfer) async throws -> Data
    ) async throws -> String {
        let params = try createStakingSignRawMessage(
            pool: pool,
            amount: amount
        )
        
        let seqno = try await sendService.loadSeqno(wallet: wallet)
        let timeout = await sendService.getTimeoutSafely(wallet: wallet)
        
        return try await ExternalMessageTransferBuilder
          .externalMessageTransfer(
            wallet: wallet,
            sender: try wallet.address,
            seqno: seqno,
            internalMessages: { sender in
                [.internal(to: params.to, value: amount, body: params.payload)]
            },
            timeout: timeout,
            signClosure: signClosure
          )
    }
}

private extension SendConfirmationController {
    // whales
    func createWhalesAddStakeCommand() throws -> Cell {
        let queryId = UInt64(Date().timeIntervalSince1970)
        let builder = Builder()
        try builder.store(uint: 2077040623, bits: 32)
        try builder.store(uint: queryId, bits: 64)
        try builder.storeMaybe(coins: Coins(rawValue: BigUInt("100000")))
        return try builder.endCell()
    }
    
    // liquid tf
    func createLiquidTfAddStakeCommand() throws -> Cell {
        let queryId = UInt64(Date().timeIntervalSince1970)
        let builder = Builder()
        try builder.store(uint: 0x47d54391, bits: 32)
        try builder.store(uint: queryId, bits: 64)
        try builder.store(uint: 0x000000000005b7ce, bits: 64)
        return try builder.endCell()
    }
    
    // tf
    func createTfAddStakeCommand() throws -> Cell {
        let builder = Builder()
        try builder.store(uint: 0, bits: 32)
        try builder.writeSnakeData(Data("d".utf8))
        return try builder.endCell()
    }
    
    // send
    func createStakingSignRawMessage(
        pool: PoolInfo,
        amount: BigUInt
    ) throws -> (to: Address, amount: BigUInt, payload: Cell) {
        let withdrawalFee = getWithdrawalFee(pool: pool)
        let address = try Address.parse(pool.address)
        
        switch pool.implementationType {
        case .whales:
            let payload = try createWhalesAddStakeCommand()
            return (address, amount, payload)
        case .liquidTF:
            let payload = try createLiquidTfAddStakeCommand()
            let amountWithFee = amount + withdrawalFee
            return (address, amountWithFee, payload)
        case .tf:
            let payload = try createTfAddStakeCommand()
            return (address, amount, payload)
        default:
            throw Error.failedToSign
        }
    }
    
    func getWithdrawalFee(pool: PoolInfo) -> BigUInt {
        switch pool.implementationType {
        case .whales:
            return BigUInt("200000000")
        case .liquidTF, .tf:
            return BigUInt("1000000000")
        default:
            return BigUInt("0")
        }
    }
}

extension String {
  var percentEncoded: String? {
    let set = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    return (self as NSString).addingPercentEncoding(withAllowedCharacters: set)
  }
}
