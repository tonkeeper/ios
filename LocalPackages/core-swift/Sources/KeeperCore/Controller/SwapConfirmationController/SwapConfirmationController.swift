import UIKit
import BigInt
import TonSwift

public final class SwapConfirmationController {
  
  public enum Error: Swift.Error {
    case failedToCalculateFee
    case failedToSendTransaction
    case failedToSign
  }
  
  public var didGetExternalSign: ((URL) async throws -> Data?)?
  
  private let wallet: Wallet
  private let swapTransactionItem: SwapTransactionItem
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let mnemonicRepository: WalletMnemonicRepository
  
  init(wallet: Wallet,
       swapTransactionItem: SwapTransactionItem,
       sendService: SendService,
       blockchainService: BlockchainService,
       mnemonicRepository: WalletMnemonicRepository) {
    self.wallet = wallet
    self.swapTransactionItem = swapTransactionItem
    self.sendService = sendService
    self.blockchainService = blockchainService
    self.mnemonicRepository = mnemonicRepository
  }
  
  public func sendTransaction() async throws {
//    do {
//      let transactionBoc = try await createTransactionBoc()
//      let transactionInfo = try await sendService.loadTransactionInfo(boc: transactionBoc)
//      NotificationCenter.default.post(
//        name: NSNotification.Name(rawValue: "didSendTransaction"),
//        object: nil,
//        userInfo: ["Wallet": wallet]
//      )
//    } catch {
//      throw error
//    }
  }
}

private extension SwapConfirmationController {
  func createTransactionBoc() async throws -> String {
    let boc: String
    switch swapTransactionItem {
    case .jettonToJetton(let swapItem):
      boc = try await createSwapTransactionBoc(
        from: swapItem.fromAddress,
        to: swapItem.toAddress,
        minAskAmount: swapItem.minAskAmount,
        offerAmount: swapItem.offerAmount,
        signClosure: { transfer in
          return try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
        })
    case .jettonToTon(let swapItem):
      boc = try await createSwapTransactionBoc(
        from: swapItem.fromAddress,
        minAskAmount: swapItem.minAskAmount,
        offerAmount: swapItem.offerAmount,
        signClosure: { transfer in
          return try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
        })
    case .tonToJetton(let swapItem):
      boc = try await createSwapTransactionBoc(
        to: swapItem.toAddress,
        minAskAmount: swapItem.minAskAmount,
        offerAmount: swapItem.offerAmount,
        signClosure: { transfer in
          return try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
        })
    }
    return boc
  }
  
  /// Jetton to Jetton swap
  func createSwapTransactionBoc(from: Address, to: Address, minAskAmount: BigUInt, offerAmount: BigUInt, signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    let seqno = try await sendService.loadSeqno(address: wallet.address)
    
    let fromWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: from.toRaw(),
      owner: wallet.address.toRaw()
    )
    
    let toWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: to.toRaw(),
      owner: STONFI_CONSTANTS.RouterAddress
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
    let seqno = try await sendService.loadSeqno(address: wallet.address)
    
    let fromWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: from.toRaw(),
      owner: wallet.address.toRaw()
    )
    
    let toWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: STONFI_CONSTANTS.TONProxyAddress,
      owner: STONFI_CONSTANTS.RouterAddress
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
    let seqno = try await sendService.loadSeqno(address: wallet.address)
    
    let fromWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: STONFI_CONSTANTS.TONProxyAddress,
      owner: STONFI_CONSTANTS.RouterAddress
    )
    
    let toWalletAddress = try await blockchainService.getWalletAddress(
      jettonMaster: to.toRaw(),
      owner: STONFI_CONSTANTS.RouterAddress
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
