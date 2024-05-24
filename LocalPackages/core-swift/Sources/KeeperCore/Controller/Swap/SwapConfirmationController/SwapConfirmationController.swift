import Foundation
import TonSwift
import BigInt

public final class SwapConfirmationController {
  
  public enum Error: Swift.Error {
    case failedToCalculateFee
    case failedToSendTransaction
    case failedToSign
  }
  
  private let wallet: Wallet
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let swapService: SwapService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let mnemonicRepository: WalletMnemonicRepository
  private let amountFormatter: AmountFormatter
  
  public var didGetError: ((Error) -> Void)?
  public var didGetExternalSign: ((URL) async throws -> Data?)?

  init(
    wallet: Wallet,
    sendService: SendService,
    blockchainService: BlockchainService,
    swapService: any SwapService,
    tonRatesStore: TonRatesStore,
    currencyStore: CurrencyStore,
    mnemonicRepository: WalletMnemonicRepository,
    amountFormatter: AmountFormatter) {
      self.wallet = wallet
      self.sendService = sendService
      self.blockchainService = blockchainService
      self.swapService = swapService
      self.tonRatesStore = tonRatesStore
      self.currencyStore = currencyStore
      self.mnemonicRepository = mnemonicRepository
      self.amountFormatter = amountFormatter
  }

  public func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    guard !input.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = input.components(separatedBy: fractionalSeparator)
    guard components.count < 3 else {
      return (0, targetFractionalDigits)
    }
    
    var fractionalDigits = 0
    if components.count == 2 {
        let fractionalString = components[1]
        fractionalDigits = fractionalString.count
    }
    let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
    let bigIntValue = BigUInt(stringLiteral: components.joined() + zeroString)
    return (bigIntValue, targetFractionalDigits)
  }
  
  public func convertAmountToInputString(amount: BigUInt, token: SwapToken) -> String {
    let tokenFractionDigits: Int
    switch token {
    case .ton:
      tokenFractionDigits = TonInfo.fractionDigits
    case .jetton(let jettonItem):
      tokenFractionDigits = jettonItem.decimals
    }
    let formatted = amountFormatter.formatAmount(
      amount,
      fractionDigits: tokenFractionDigits,
      maximumFractionDigits: tokenFractionDigits
    )
    return formatted
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

  /// Jetton to Jetton swap
  func createSwapTransactionBoc(from: Address, to: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    
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
      signClosure: signClosure
    )
  }
  
  /// Jetton to TON swap
  func createSwapTransactionBoc(from: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    
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
      signClosure: signClosure
    )
  }
  
  /// TON to Jetton swap
  func createSwapTransactionBoc(to: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    
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
      signClosure: signClosure
    )
  }
  
  public func sendTransaction(sellItem: SwapItem, buyItem: SwapItem, estimate: SwapEstimate) async throws {
    do {
      var boc: String? = nil
      switch sellItem.token {
      case .ton:
        // ton to jetton
        switch buyItem.token {
        case .ton:
          break
        case .jetton(let asset):
          boc = try await createSwapTransactionBoc(to: try Address.parse(asset.contractAddress ?? ""),
                                                   minAskAmount: BigUInt(estimate.minAskUnits!),
                                                   offerAmount: BigUInt(estimate.offerUnits!)) { transfer in
            return try await signTransfer(transfer)
          }
          break
        }
        break
      case .jetton(let fromAsset):
          switch buyItem.token {
          case .ton:
            // jetton to ton
            boc = try await createSwapTransactionBoc(from: try Address.parse(fromAsset.contractAddress ?? ""),
                                                     minAskAmount: BigUInt(estimate.minAskUnits!),
                                                     offerAmount: BigUInt(estimate.offerUnits!)) { transfer in
              return try await signTransfer(transfer)
            }
            break
          case .jetton(let toAsset):
            // jetton to jetton
            boc = try await createSwapTransactionBoc(from: try Address.parse(fromAsset.contractAddress ?? ""),
                                                     to: try Address.parse(toAsset.contractAddress ?? ""),
                                                     minAskAmount: BigUInt(estimate.minAskUnits!),
                                                     offerAmount: BigUInt(estimate.offerUnits!)) { transfer in
              return try await signTransfer(transfer)
            }
            break
          }
        break
      }
      guard let transactionBoc = boc else {
        return
      }
      try await sendService.sendTransaction(boc: transactionBoc, wallet: wallet)
      NotificationCenter.default.post(
        name: NSNotification.Name(rawValue: "didSendTransaction"),
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

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}
