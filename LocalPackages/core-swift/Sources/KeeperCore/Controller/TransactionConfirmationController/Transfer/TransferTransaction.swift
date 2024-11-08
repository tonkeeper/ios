import Foundation
import TonSwift
import BigInt

final class TransferTransaction {
  
  enum Error: Swift.Error {
    case sendTransactionFailed
  }
  
  enum Transfer {
    case ton(amount: BigUInt)
    case jetton(JettonItem, amount: BigUInt)
    case nft(NFT, transferAmount: BigUInt)
  }
  
  struct TransferPayload {
    enum TransferType {
      case `default`
      case battery(excessAddress: Address)
    }
    
    var isBattery: Bool {
      switch self.type {
      case .default:
        return false
      case .battery:
        return true
      }
    }
    
    let type: TransferType
    let fee: UInt64
  }
  
  private let tonProofTokenService: TonProofTokenService
  private let sendService: SendService
  private let batteryService: BatteryService
  private let balanceStore: BalanceStore
  private let accountService: AccountService
  private let configuration: Configuration
  
  init(tonProofTokenService: TonProofTokenService,
       sendService: SendService,
       batteryService: BatteryService,
       balanceStore: BalanceStore,
       accountService: AccountService,
       configuration: Configuration) {
    self.tonProofTokenService = tonProofTokenService
    self.sendService = sendService
    self.batteryService = batteryService
    self.balanceStore = balanceStore
    self.accountService = accountService
    self.configuration = configuration
  }
  
  func sendTransaction(wallet: Wallet,
                       transfer: Transfer,
                       recipient: Recipient,
                       comment: String?,
                       transferType: TransferPayload.TransferType,
                       signClosure: (TransferData) async throws -> String) async throws {
    switch transferType {
    case .default:
      let transferData = try await createWalletTransfer(
        wallet: wallet,
        transfer: transfer,
        recipient: recipient,
        comment: comment,
        responseAddress: nil,
        messageType: .ext
      )
      let boc = try await signClosure(transferData)
      try await sendService.sendTransaction(boc: boc, wallet: wallet)
    case .battery(let excessAddress):
      let transferData = try await createWalletTransfer(
        wallet: wallet,
        transfer: transfer,
        recipient: recipient,
        comment: comment,
        responseAddress: excessAddress,
        messageType: wallet.isW5Generation ? .int : .ext
      )
      let boc = try await signClosure(transferData)
      let tonProofToken = try tonProofTokenService.getWalletToken(wallet)
      try await batteryService.sendTransaction(wallet: wallet, boc: boc, tonProofToken: tonProofToken)
    }
  }
  
  func calculateFee(wallet: Wallet,
                    transfer: Transfer,
                    recipient: Recipient,
                    comment: String?,
                    withoutRelayer: Bool = false) async throws -> TransferPayload {
    let isRelayerAvailable = isRelayerAvailable(wallet: wallet, transfer: transfer)
    let tonProofToken = try? tonProofTokenService.getWalletToken(wallet)
    let batteryConfig = try? await batteryService.loadBatteryConfig(wallet: wallet)
    
    if isRelayerAvailable,
       let tonProofToken,
       let excessAccount = batteryConfig?.excessAccount,
       let excessAddress = try? Address.parse(excessAccount),
       await configuration.isBatteryEnable(isTestnet: wallet.isTestnet),
       await configuration.isBatterySendEnable(isTestnet: wallet.isTestnet) {
      return try await calculateBatteryFee(
        wallet: wallet,
        transfer: transfer,
        recipient: recipient,
        comment: comment,
        excessAddress: excessAddress,
        tonProofToken: tonProofToken
      )
    } else {
      return try await calculateDefaultFee(
        wallet: wallet,
        transfer: transfer,
        recipient: recipient,
        comment: comment
      )
    }
  }
  
  func calculateBatteryFee(wallet: Wallet,
                           transfer: Transfer,
                           recipient: Recipient,
                           comment: String?,
                           excessAddress: Address,
                           tonProofToken: String) async throws -> TransferPayload {
    let transferData = try await createWalletTransfer(
      wallet: wallet,
      transfer: transfer,
      recipient: recipient,
      comment: comment,
      responseAddress: nil,
      messageType: wallet.isW5Generation ? .int : .ext)
    let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
      .createUnsignedWalletTransfer(
        wallet: wallet
      )
    let signed = try TransferSigner.signWalletTransfer(
      walletTransfer,
      wallet: wallet,
      seqno: transferData.seqno,
      signer: WalletTransferEmptyKeySigner()
    )
    do {
      let transactionInfo = try await batteryService.loadTransactionInfo(
        wallet: wallet,
        boc: signed.toBoc().base64EncodedString(),
        tonProofToken: tonProofToken)
      if transactionInfo.isBatteryAvailable {
        return TransferPayload(type: .battery(excessAddress: excessAddress), fee: UInt64(abs(transactionInfo.info.event.extra)))
      } else {
        return try await calculateDefaultFee(wallet: wallet, transfer: transfer, recipient: recipient, comment: comment)
      }
    } catch {
      return try await calculateDefaultFee(wallet: wallet, transfer: transfer, recipient: recipient, comment: comment)
    }
  }
  
  func calculateDefaultFee(wallet: Wallet,
                           transfer: Transfer,
                           recipient: Recipient,
                           comment: String?) async throws -> TransferPayload {
    let transferData = try await createWalletTransfer(
      wallet: wallet,
      transfer: transfer,
      recipient: recipient,
      comment: comment,
      responseAddress: nil, 
      messageType: .ext)
    let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
      .createUnsignedWalletTransfer(
        wallet: wallet
      )
    let signed = try TransferSigner.signWalletTransfer(
      walletTransfer,
      wallet: wallet,
      seqno: transferData.seqno,
      signer: WalletTransferEmptyKeySigner()
    )
    
    let transactionInfo = try await sendService.loadTransactionInfo(boc: signed.toBoc().hexString(), wallet: wallet)
    return TransferPayload(type: .default, fee: UInt64(abs(transactionInfo.event.extra)))
  }
  
  private func isRelayerAvailable(wallet: Wallet, transfer: Transfer) -> Bool {
    switch transfer {
    case .ton:
      return false
    case .jetton:
      return wallet.isBatteryEnable && wallet.batterySettings.isJettonTransactionEnable
    case .nft:
      return wallet.isBatteryEnable && wallet.batterySettings.isNFTTransactionEnable
    }
  }
  
  private func createWalletTransfer(wallet: Wallet,
                                    transfer: Transfer,
                                    recipient: Recipient,
                                    comment: String?,
                                    responseAddress: Address?,
                                    messageType: MessageType) async throws -> TransferData {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    
    let transferData: TransferData = try await {
      switch transfer {
      case .ton(let amount):
        return try await createTonWalletTransfer(
          wallet: wallet,
          amount: amount,
          recipient: recipient,
          comment: comment,
          seqno: seqno,
          timeout: timeout,
          messageType: messageType
        )
      case .jetton(let jettonItem, let amount):
        return try await createJettonWalletTransfer(
          wallet: wallet,
          jettonItem: jettonItem,
          amount: amount,
          recipient: recipient,
          comment: comment,
          responseAddress: responseAddress,
          seqno: seqno,
          timeout: timeout,
          messageType: messageType
        )
      case .nft(let nft, let transferAmount):
        return try await createNFTWalletTransfer(
          wallet: wallet,
          nft: nft,
          recipient: recipient,
          comment: comment,
          responseAddress: responseAddress,
          transferAmount: transferAmount,
          seqno: seqno,
          timeout: timeout,
          messageType: messageType
        )
      }
    }()
    
    return transferData
  }
  
  private func createTonWalletTransfer(wallet: Wallet,
                                       amount: BigUInt,
                                       recipient: Recipient,
                                       comment: String?,
                                       seqno: UInt64,
                                       timeout: UInt64,
                                       messageType: MessageType) async throws -> TransferData {
    let account = try? await accountService.loadAccount(isTestnet: wallet.isTestnet, address: recipient.recipientAddress.address)
    let shouldForceBounceFalse = ["empty", "uninit", "nonexist"].contains(account?.status)
    
    let isMax: Bool
    if let balance = balanceStore.state[wallet]?.walletBalance {
      isMax = BigUInt(balance.balance.tonBalance.amount) == amount
    } else {
      isMax = false
    }
    
    return TransferData(
      transfer: .ton(
        TransferData.Ton(
          amount: amount,
          isMax: isMax,
          recipient: recipient.recipientAddress.address,
          isBouncable: shouldForceBounceFalse ? false : recipient.recipientAddress.isBouncable,
          comment: comment
        )
      ),
      wallet: wallet,
      messageType: messageType,
      seqno: seqno,
      timeout: timeout
    )
  }
  
  private func createJettonWalletTransfer(wallet: Wallet,
                                          jettonItem: JettonItem,
                                          amount: BigUInt,
                                          recipient: Recipient,
                                          comment: String?,
                                          responseAddress: Address?,
                                          seqno: UInt64,
                                          timeout: UInt64, 
                                          messageType: MessageType) async throws -> TransferData {
    var customPayload: Cell?
    var stateInit: StateInit?
    
    if jettonItem.jettonInfo.hasCustomPayload,
       let payload = try? await sendService.getJettonCustomPayload(wallet: wallet, jetton: jettonItem.jettonInfo.address) {
      customPayload = payload.customPayload
      if let payloadStateInit = payload.stateInit {
        stateInit = try? StateInit.loadFrom(slice: payloadStateInit.beginParse())
      }
    }
    
    return TransferData(
      transfer: .jetton(
        TransferData.Jetton(
          jettonAddress: jettonItem.walletAddress,
          amount: amount,
          recipient: recipient.recipientAddress.address,
          responseAddress: responseAddress,
          comment: comment,
          customPayload: customPayload,
          stateInit: stateInit
        )
      ),
      wallet: wallet,
      messageType: messageType,
      seqno: seqno,
      timeout: timeout
    )
  }
  
  private func createNFTWalletTransfer(wallet: Wallet,
                                       nft: NFT,
                                       recipient: Recipient,
                                       comment: String?,
                                       responseAddress: Address?,
                                       transferAmount: BigUInt,
                                       seqno: UInt64,
                                       timeout: UInt64,
                                       messageType: MessageType) async throws -> TransferData {
    var commentCell: Cell?
    if let comment = comment {
      commentCell = try Builder().store(int: 0, bits: 32).writeSnakeData(Data(comment.utf8)).endCell()
    }
    
    return TransferData(
      transfer: .nft(
        TransferData.NFT(
          nftAddress: nft.address,
          recipient: recipient.recipientAddress.address,
          responseAddress: responseAddress,
          isBouncable: recipient.recipientAddress.isBouncable,
          transferAmount: transferAmount.magnitude,
          forwardPayload: commentCell
        )
      ), wallet: wallet,
      messageType: messageType,
      seqno: seqno,
      timeout: timeout
    )
  }
}
