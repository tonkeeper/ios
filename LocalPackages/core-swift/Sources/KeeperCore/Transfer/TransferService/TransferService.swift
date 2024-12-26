import Foundation
import TonSwift
import BigInt
import TonAPI

public struct TransferEmulationResult {
  public let transactionInfo: MessageConsequences
  public let transferType: TransferType
}

public enum TransferType {
  case `default`
  case battery(excessAddress: Address)
  
  public var isBattery: Bool {
    switch self {
    case .default:
      return false
    case .battery:
      return true
    }
  }
  
  public var excessAddress: Address? {
    switch self {
    case .default:
      return nil
    case .battery(let excessAddress):
      return excessAddress
    }
  }
}

public struct TransferService {
  
  private let tonProofTokenService: TonProofTokenService
  private let batteryService: BatteryService
  private let balanceService: BalanceService
  private let sendService: SendService
  private let accountService: AccountService
  private let configuration: Configuration
  
  init(tonProofTokenService: TonProofTokenService,
       batteryService: BatteryService,
       balanceService: BalanceService,
       sendService: SendService,
       accountService: AccountService,
       configuration: Configuration) {
    self.tonProofTokenService = tonProofTokenService
    self.batteryService = batteryService
    self.balanceService = balanceService
    self.sendService = sendService
    self.accountService = accountService
    self.configuration = configuration
  }
  
  @discardableResult
  public func sendTransaction(wallet: Wallet,
                              transfer: Transfer,
                              transferType: TransferType,
                              signClosure: (TransferData) async throws -> SignedTransactions) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let transferData = try await createTransferData(
      wallet: wallet,
      transfer: transfer,
      seqno: seqno,
      transferType: transferType
    )
    let signedTransactions = try await signClosure(transferData)
    
    if (signedTransactions.count == 1) {
      let boc = signedTransactions[0]
      switch transferType {
      case .default:
        try await sendService.sendTransaction(
          boc: boc,
          wallet: wallet
        )
      case .battery:
        let tonProofToken = try tonProofTokenService.getWalletToken(wallet)
        try await batteryService.sendTransaction(
          wallet: wallet,
          boc: boc,
          tonProofToken: tonProofToken
        )
      }
    } else {
      switch transferType {
      case .default:
        try await sendService.sendTransactions(
          batch: signedTransactions,
          wallet: wallet
        )
      case .battery:
        let tonProofToken = try tonProofTokenService.getWalletToken(wallet)
        for boc in signedTransactions {
          try await batteryService.sendTransaction(
            wallet: wallet,
            boc: boc,
            tonProofToken: tonProofToken
          )
        }
      }
    }
    
    return signedTransactions[0]
  }
  
  public func emulate(wallet: Wallet,
                      transfer: Transfer,
                      params: [EmulateMessageToWalletRequestParamsInner]? = nil) async throws -> TransferEmulationResult {
    let tonProofToken = try? tonProofTokenService.getWalletToken(wallet)
    let batteryConfig = try? await batteryService.loadBatteryConfig(wallet: wallet)
    
    
    if let tonProofToken,
       await isRelayerAvailable(wallet: wallet, tonProofToken: tonProofToken, transfer: transfer),
       await configuration.isBatteryEnable(isTestnet: wallet.isTestnet),
       await configuration.isBatterySendEnable(isTestnet: wallet.isTestnet) {
      return try await emulateWithBattery(
        wallet: wallet,
        transfer: transfer,
        excessAddress: wallet.address,
        tonProofToken: tonProofToken,
        transferType: .battery(excessAddress: wallet.address)
      )
    } else {
      return try await defaultEmulate(
        wallet: wallet,
        transfer: transfer,
        params: params
      )
    }
  }
  
  private func emulateWithBattery(wallet: Wallet,
                                  transfer: Transfer,
                                  excessAddress: Address,
                                  tonProofToken: String,
                                  transferType: TransferType) async throws -> TransferEmulationResult {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    do {
      let transferData = try await createTransferData(
        wallet: wallet,
        transfer: transfer,
        seqno: seqno,
        transferType: transferType
      )
      let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
        .createUnsignedWalletTransfer(wallet: wallet)
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
          tonProofToken: tonProofToken
        )
        if transactionInfo.isBatteryAvailable {
          return TransferEmulationResult(
            transactionInfo: transactionInfo.info,
            transferType: .battery(excessAddress: excessAddress)
          )
        } else {
          return try await defaultEmulate(
            wallet: wallet,
            transfer: transfer
          )
        }
      } catch {
        return try await defaultEmulate(
          wallet: wallet,
          transfer: transfer
        )
      }
    } catch {
      throw error
    }
  }
  
  private func defaultEmulate(wallet: Wallet,
                              transfer: Transfer,
                              params: [EmulateMessageToWalletRequestParamsInner]? = nil) async throws -> TransferEmulationResult {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let transferData = try await createTransferData(
      wallet: wallet,
      transfer: transfer,
      seqno: seqno,
      transferType: .default
    )
    let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
      .createUnsignedWalletTransfer(wallet: wallet)
    let signed = try TransferSigner.signWalletTransfer(
      walletTransfer,
      wallet: wallet,
      seqno: transferData.seqno,
      signer: WalletTransferEmptyKeySigner()
    )
    let transactionInfo = try await sendService.loadTransactionInfo(
      boc: signed.toBoc().hexString(),
      wallet: wallet,
      params: params)
    return TransferEmulationResult(
      transactionInfo: transactionInfo,
      transferType: .default
    )
  }
  
  private func createTransferData(wallet: Wallet,
                                  transfer: Transfer,
                                  seqno: UInt64,
                                  transferType: TransferType) async throws -> TransferData {
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let messageType: MessageType = {
      switch transferType {
      case .default:
        return .ext
      case .battery:
        return wallet.isW5Generation ? .int : .ext
      }
    }()
    let responseAddress: Address? = transferType.excessAddress
    
    switch transfer {
    case let .ton(amount, recipient, comment):
      let account = try? await accountService.loadAccount(isTestnet: wallet.isTestnet, address: recipient.recipientAddress.address)
      let shouldForceBounceFalse = ["empty", "uninit", "nonexist"].contains(account?.status)
      let isMax = await {
        do {
          let balance = try await balanceService.loadWalletBalance(wallet: wallet, currency: .USD)
          return BigUInt(balance.balance.tonBalance.amount) == amount
        } catch {
          return false
        }
      }()
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
    case let .jetton(jettonItem, transferAmount, amount, recipient, comment):
      var customPayload: Cell?
      var stateInit: TonSwift.StateInit?
      
      if jettonItem.jettonInfo.hasCustomPayload,
         let payload = try? await sendService.getJettonCustomPayload(
          wallet: wallet,
          jetton: jettonItem.jettonInfo.address) {
        customPayload = payload.customPayload
        if let payloadStateInit = payload.stateInit {
          stateInit = try? StateInit.loadFrom(slice: payloadStateInit.beginParse())
        }
      }
      
      return TransferData(
        transfer: .jetton(
          TransferData.Jetton(
            transferAmount: transferAmount,
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
    case let .nft(nft, transferAmount, recipient, comment):
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
            isBouncable: true,
            transferAmount: transferAmount.magnitude,
            forwardPayload: commentCell
          )
        ),
        wallet: wallet,
        messageType: messageType,
        seqno: seqno,
        timeout: timeout
      )
    case .stonfiSwap(let signRawRequest):
      return TransferData(
        transfer: try await createTransferDataTransfer(
          wallet: wallet,
          signRawRequest: signRawRequest,
          seqno: seqno,
          timout: timeout,
          excessesAddress: transferType.excessAddress
        ),
        wallet: wallet,
        messageType: messageType,
        seqno: seqno,
        timeout: timeout
      )
    case .signRaw(let signRawRequest, _):
      return TransferData(
        transfer: try await createTransferDataTransfer(
          wallet: wallet,
          signRawRequest: signRawRequest,
          seqno: seqno,
          timout: timeout,
          excessesAddress: transferType.excessAddress
        ),
        wallet: wallet,
        messageType: messageType,
        seqno: seqno,
        timeout: timeout
      )
    case .renewDNS(let nft):
      return TransferData(
        transfer: TransferData.Transfer.changeDNSRecord(
          .renew(
            TransferData.ChangeDNSRecord.RenewDNS(
              nftAddress: nft.address,
              linkAmount: OP_AMOUNT.CHANGE_DNS_RECORD
            )
          )
        ),
        wallet: wallet,
        messageType: messageType,
        seqno: seqno,
        timeout: timeout
      )
    }
  }
  
  private func createTransferDataTransfer(wallet: Wallet,
                                          signRawRequest: SignRawRequest,
                                          seqno: UInt64,
                                          timout: UInt64,
                                          excessesAddress: Address?) async throws -> TransferData.Transfer {
    let jettonsBalance = try await balanceService.loadWalletBalance(
      wallet: wallet,
      currency: .USD
    ).balance.jettonsBalance
    
    var rebuildedMessages: [SignRawRequestMessage] = []
    for message in signRawRequest.messages {
      let foundJetton = jettonsBalance.first(where: { $0.item.walletAddress == message.address.address })
      
      guard let jetton = foundJetton else {
        rebuildedMessages.append(message)
        continue
      }
      
      if (!jetton.item.jettonInfo.hasCustomPayload) {
        rebuildedMessages.append(message)
        continue
      }
      
      let jettonPayload = try await sendService.getJettonCustomPayload(wallet: wallet, jetton: jetton.item.jettonInfo.address)
      
      guard let jettonSendPayload = message.payload else {
        rebuildedMessages.append(message)
        continue
      }
      var jettonTransferData = try JettonTransferData.loadFrom(
        slice: Cell.fromBase64(src: jettonSendPayload).beginParse()
      )
      
      jettonTransferData.customPayload = jettonPayload.customPayload
      
      let stateInit: String? = try jettonPayload.stateInit != nil
      ? jettonPayload.stateInit?.toBoc().base64EncodedString()
      : message.stateInit
      let payload: String? = try Builder().store(jettonTransferData).endCell().toBoc().base64EncodedString()
      
      rebuildedMessages.append(SignRawRequestMessage(
        address: message.address,
        amount: message.amount,
        stateInit: stateInit,
        payload: payload
      ))
    }

    let payloads: [TransferData.TonConnect.Payload] = try rebuildedMessages.map {
      var resultPayload: String? = $0.payload
      if let payload = $0.payload, let excessesAddress {
        var payloadCell = try Cell.fromBase64(src: payload.fixBase64())
        payloadCell = try rebuildPayloadWithExcessesAddress(payload: payloadCell, excessesAddress)
        resultPayload = try payloadCell.toBoc().base64EncodedString()
      }
      
      return TransferData.TonConnect.Payload(
        value: BigInt(integerLiteral: Int64($0.amount)),
        recipientAddress: $0.address,
        stateInit: $0.stateInit,
        payload: resultPayload
      )
    }
    
    let transfer = TransferData.Transfer.tonConnect(
      TransferData.TonConnect(
        payloads: payloads,
        sender: signRawRequest.from
      )
    )
    return transfer
  }
  
  private func rebuildPayloadWithExcessesAddress(payload: Cell, _ excessesAddress: Address) throws -> Cell {
    
    let payloadSlice = try payload.toSlice()
    guard let opcode = try? payloadSlice.loadUint(bits: 32),
          opcode <= Int32.max else {
      return payload
    }
    let builder = Builder()
  
    switch Int32(opcode) {
    case OpCodes.STONFI_SWAP:
      try builder.store(uint: OpCodes.STONFI_SWAP, bits: 32)
      try builder.store(payloadSlice.loadType() as Address)
      try builder.store(payloadSlice.loadCoins())
      try builder.store(payloadSlice.loadType() as Address)
      try builder.store(bit: true)
      try builder.store(excessesAddress)
    case OpCodes.STONFI_SWAP_V2:
      try builder.store(uint: OpCodes.STONFI_SWAP_V2, bits: 32)
      try builder.store(payloadSlice.loadType() as Address)
      try builder.store(payloadSlice.loadType() as Address)
      let _ : TonSwift.AnyAddress = try payloadSlice.loadType()
      try builder.store(excessesAddress)
      try builder.store(uint: payloadSlice.loadUint(bits: 64), bits: 64)
      try builder.store(ref: payloadSlice.loadRef())
    case OpCodes.JETTON_TRANSFER:
      try builder.store(uint: OpCodes.JETTON_TRANSFER, bits: 32)
      try builder.store(uint: payloadSlice.loadUint(bits: 64), bits: 64)
      try builder.store(payloadSlice.loadCoins())
      try builder.store(payloadSlice.loadType() as Address)
      let _ : TonSwift.AnyAddress = try payloadSlice.loadType()
      while payloadSlice.remainingRefs > 0 {
        let forwardCell = try payloadSlice.loadRef()
        let rebuildedRef = try rebuildPayloadWithExcessesAddress(payload: forwardCell, excessesAddress)
        try builder.store(ref: rebuildedRef)
      }
      try builder.store(excessesAddress)
      try builder.store(bits: payloadSlice.loadBits(payloadSlice.remainingBits))
    default:
      return payload
    }
    
    let cell = try builder.endCell()
    return cell
  }
  
  private func isRelayerAvailable(wallet: Wallet,
                                  tonProofToken: String,
                                  transfer: Transfer) async -> Bool {
    
    let isBalanceAvailable: () async -> Bool = {
      return await isBatteryBalanceEnable(wallet: wallet, tonProofToken: tonProofToken)
    }
    switch transfer {
    case .ton:
      return false
    case .jetton:
      let isBalanceAvailable = await isBalanceAvailable()
      return wallet.isBatteryEnable && wallet.batterySettings.isJettonTransactionEnable && isBalanceAvailable
    case .nft:
      let isBalanceAvailable = await isBalanceAvailable()
      return wallet.isBatteryEnable && wallet.batterySettings.isNFTTransactionEnable && isBalanceAvailable
    case .stonfiSwap:
      let isBalanceAvailable = await isBalanceAvailable()
      return wallet.isBatteryEnable && wallet.batterySettings.isSwapTransactionEnable && isBalanceAvailable
    case .signRaw(_, let isForceRelayer):
      return isForceRelayer
    case .renewDNS:
      return false
    }
  }
  
  func isBatteryBalanceEnable(wallet: Wallet, tonProofToken: String) async -> Bool {
    do {
      let batteryBalance = try await batteryService.loadBatteryBalance(wallet: wallet, tonProofToken: tonProofToken)
      let compareResult = batteryBalance.balanceDecimalNumber.compare(0)
      return compareResult == .orderedDescending
    } catch {
      return false
    }
  }
}
