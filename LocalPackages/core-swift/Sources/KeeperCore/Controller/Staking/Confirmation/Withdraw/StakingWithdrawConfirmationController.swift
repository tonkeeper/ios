import Foundation
import TonSwift
import BigInt

final class StakingWithdrawConfirmationController: StakingConfirmationController {
  public var didUpdateModel: ((StakingConfirmationModel) -> Void)?
  public var didGetError: ((StakingConfirmationError) -> Void)?
  public var didGetExternalSign: ((URL) async throws -> Data?)?
  
  private let withdrawModel: WithdrawModel
  private let amount: BigUInt
  
  private let balanceStore: BalanceStore
  private let ratesStore: RatesStore
  private let walletsStore: WalletsStore
  private let currencyStore: CurrencyStore
  private let mnemonicRepository: WalletMnemonicRepository
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  private let sendService: SendService
  private let blockchainService: BlockchainService
  
  init(
    withdrawModel: WithdrawModel,
    amount: BigUInt,
    walletsStore: WalletsStore,
    balanceStore: BalanceStore,
    ratesStore: RatesStore,
    currencyStore: CurrencyStore,
    mnemonicRepository: WalletMnemonicRepository,
    amountFormatter: AmountFormatter,
    decimalFormatter: DecimalAmountFormatter,
    sendService: SendService,
    blockchainService: BlockchainService
  ) {
    self.withdrawModel = withdrawModel
    self.amount = amount
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.mnemonicRepository = mnemonicRepository
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
    self.sendService = sendService
    self.blockchainService = blockchainService
  }
  
  public func start() async {
    let model = await makeModel(fee: .loading, feeConverted: .value(nil))
    await MainActor.run {
      didUpdateModel?(model)
    }
    await emulate()
  }
  
  public func sendTransaction() async throws {
    do {
      let transactionBoc = try await createTransactionBoc {
        try await signTransfer($0)
      }
      
      try await sendService.sendTransaction(boc: transactionBoc, wallet: walletsStore.activeWallet)
      NotificationCenter.default.post(
        name: NSNotification.Name(rawValue: "didSendTransaction"),
        object: nil,
        userInfo: ["Wallet": walletsStore.activeWallet]
      )
    } catch {
      Task { @MainActor in
        didGetError?(.failedToSendTransaction)
      }
      throw error
    }
  }
  
  public func isNeedToConfirm() -> Bool {
    return walletsStore.activeWallet.isRegular
  }
}

// MARK: - Private methods

private extension StakingWithdrawConfirmationController {
  func emulate() async {
    async let createTransactionBocTask = createTransactionBoc {
      try $0.signMessage(signer: WalletTransferEmptyKeySigner())
    }
    
    do {
      let transactionBoc = try await createTransactionBocTask
      let transactionInfo = try await sendService.loadTransactionInfo(
        boc: transactionBoc,
        wallet: walletsStore.activeWallet
      )
      
      let fee = transactionInfo.trace.transaction.total_fees
      let model = await makeEmulatedModel(fee: fee)
      
      Task { @MainActor in
        didUpdateModel?(model)
      }
    } catch {
      let model = await makeEmulatedModel(fee: nil)
      Task { @MainActor in
        didUpdateModel?(model)
        didGetError?(.failedToCalculateFee)
      }
    }
  }
  
  func makeEmulatedModel(fee: Int64?) async -> StakingConfirmationModel {
    let feeItem: LoadableModelItem<String>
    let feeConverted: LoadableModelItem<String?>
    if let fee = fee {
      let feeFormatted = amountFormatter.formatAmount(
        BigUInt(UInt64(fee)),
        fractionDigits: withdrawModel.token.fractionDigits,
        maximumFractionDigits: withdrawModel.token.fractionDigits,
        symbol: TonInfo.symbol
      )
      feeItem = .value(feeFormatted)
      let rates = ratesStore.getRates(jettons: [])
      let currency = await currencyStore.getActiveCurrency()
      if let rates = rates.ton.first(where: { $0.currency == currency }) {
        let rateConverter = RateConverter()
        let converted = rateConverter.convert(
          amount: fee,
          amountFractionLength: withdrawModel.token.fractionDigits,
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
      feeItem = .value("-")
      feeConverted = .value(nil)
    }
    
    return await makeModel(fee: feeItem, feeConverted: feeConverted)
  }
  
  func makeModel(
    fee: LoadableModelItem<String>,
    feeConverted: LoadableModelItem<String?>
  ) async -> StakingConfirmationModel {
    let pool = withdrawModel.pool
    
    let poolName = pool.name
    let poolImage: StakingPoolImage = .fromResource
    
    var formattedConvertedAmount: String?
    
    let formattedAmount = amountFormatter.formatAmount(
      amount,
      fractionDigits: withdrawModel.token.fractionDigits,
      maximumFractionDigits: withdrawModel.token.fractionDigits
    )
    
    let rates = ratesStore.getRates(jettons: []).ton
    let currency = await currencyStore.getActiveCurrency()
    if let rates = rates.first(where: { $0.currency == currency }) {
      let rateConverter = RateConverter()
      let converted = rateConverter.convert(
        amount: amount,
        amountFractionLength: withdrawModel.token.fractionDigits,
        rate: rates
      )
      
      formattedConvertedAmount = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
    }
    
    return  .init(
      poolName: poolName,
      poolImage: poolImage,
      wallet: walletsStore.activeWallet.model.emojiLabel,
      apyPercent: nil,
      amount: formattedAmount,
      amountConverted: formattedConvertedAmount,
      fee: fee,
      feeConverted: feeConverted,
      kind: pool.implementation.type,
      tokenSymbol: withdrawModel.token.symbol
    )
  }
  
  func createTransactionBoc(
    signClosure: (WalletTransfer) async throws -> Data
  ) async throws -> String {
    let pool = withdrawModel.pool
    let wallet = walletsStore.activeWallet
    let jettonRawAddress = withdrawModel.lpJetton.address.toRaw()
    let withdrawFee = pool.implementation.withdrawalFee
    
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let jettonWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: jettonRawAddress,
      owner: wallet.address.toRaw(),
      isTestnet: wallet.isTestnet
    )
    
    return try await StakingMessageBuilder.withdraw(
      poolImplementation: pool.implementation,
      wallet: wallet,
      seqno: seqno,
      jettonWalletAddress: jettonWalletAddress,
      amount: amount,
      withdrawFee: withdrawFee,
      signClosure: signClosure
      )
  }
  
  func signTransfer(_ transfer: WalletTransfer) async throws -> Data {
    switch walletsStore.activeWallet.identity.kind {
    case .Regular:
      let mnemonic = try mnemonicRepository.getMnemonic(forWallet: walletsStore.activeWallet)
      let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
      let privateKey = keyPair.privateKey
      return try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: privateKey.data))
    case .Lockup:
      throw StakingConfirmationError.failedToSign
    case .Watchonly:
      throw StakingConfirmationError.failedToSign
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
      throw StakingConfirmationError.failedToSign
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
