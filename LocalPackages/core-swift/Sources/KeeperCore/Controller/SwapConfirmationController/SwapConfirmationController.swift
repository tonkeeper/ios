import Foundation
import TonSwift
import BigInt

public final class SwapConfirmationController {

  public enum Error: Swift.Error {
    case failedToSwapTransaction
    case failedToSign
    case unrecognizedTokensToSwap
  }

  public var didGetError: ((Error) -> Void)?
  public var didGetExternalSign: ((URL) async throws -> Data?)?

  private let swapItem: SwapItem
  public let wallet: Wallet
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let mnemonicRepository: WalletMnemonicRepository

  init(swapItem: SwapItem,
       walletsStore: WalletsStore,
       sendService: SendService,
       blockchainService: BlockchainService,
       mnemonicRepository: WalletMnemonicRepository) {
    self.swapItem = swapItem
    self.wallet = walletsStore.activeWallet
    self.sendService = sendService
    self.blockchainService = blockchainService
    self.mnemonicRepository = mnemonicRepository
  }

  public func sendTransaction() async throws {
    do {
      let transactionBoc = try await createTransactionBoc()
      try await sendService.sendTransaction(boc: transactionBoc, wallet: wallet)
      NotificationCenter.default.post(
        name: NSNotification.Name(rawValue: "didSendTransaction"),
        object: nil,
        userInfo: ["Wallet": wallet]
      )
    } catch {
      Task { @MainActor in
        didGetError?(.failedToSwapTransaction)
      }
      throw error
    }
  }

  func createTransactionBoc() async throws -> String {
    if case let .jetton(jettonItem) = swapItem.receiveToken, swapItem.sendToken == .ton {
      return try await createSwapTransactionBoc(
        to: jettonItem.jettonInfo.address,
        minAskAmount: swapItem.receiveAmount,
        offerAmount: swapItem.sendAmount,
        signClosure: { transfer in
          return try await signTransfer(transfer)
        })
    } else if case let .jetton(jettonItem) = swapItem.sendToken, swapItem.receiveToken == .ton {
      return try await createSwapTransactionBoc(
        from: jettonItem.jettonInfo.address,
        minAskAmount: swapItem.receiveAmount,
        offerAmount: swapItem.sendAmount,
        signClosure: { transfer in
          return try await signTransfer(transfer)
        })
    } else if case let .jetton(sendItem) = swapItem.sendToken, case let .jetton(receiveItem) = swapItem.receiveToken {
      return try await createSwapTransactionBoc(
        from: sendItem.jettonInfo.address,
        to: receiveItem.jettonInfo.address,
        minAskAmount: swapItem.receiveAmount,
        offerAmount: swapItem.sendAmount,
        signClosure: { transfer in
          return try await signTransfer(transfer)
        })
    }
    throw Error.unrecognizedTokensToSwap
  }

  
  /// Jetton to Jetton swap
  private func createSwapTransactionBoc(from: Address, to: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
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
  private func createSwapTransactionBoc(from: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
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
  private func createSwapTransactionBoc(to: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
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

  // TODO: - Refactor shared code from SendV3Controller
  // Better move to a separate shared controller or some other layer

  public func isNeedToConfirm() -> Bool {
    return wallet.isRegular
  }

  private func signTransfer(_ transfer: WalletTransfer) async throws -> Data {
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

  private func signExternal(transfer: Data, publicKey: TonSwift.PublicKey, revision: WalletContractVersion) async throws -> Data {
    guard let url = createTonSignURL(transfer: transfer, publicKey: publicKey, revision: revision),
          let didGetExternalSign,
          let signedData = try await didGetExternalSign(url) else {
      throw Error.failedToSign
    }
    return signedData
  }
  
  private func createTonSignURL(transfer: Data, publicKey: TonSwift.PublicKey, revision: WalletContractVersion) -> URL? {
    guard let publicKey = publicKey.data.base64EncodedString().percentEncoded,
          let body = transfer.base64EncodedString().percentEncoded else { return nil }
    let v = revision.rawValue.lowercased()
    
    let string = "tonsign://?pk=\(publicKey)&body=\(body)&v=\(v)&return=\("tonkeeperx://publish".percentEncoded ?? "")"
    return URL(string: string)
  }
}
