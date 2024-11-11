import Foundation
import KeeperCore
import TonSwift
import BigInt

struct BatteryRechargeBocBuilder {
  
  private let wallet: Wallet
  private let payload: BatteryRechargePayload
  private let batteryService: BatteryService
  private let sendService: SendService
  private let tonProofTokenService: TonProofTokenService
  private let configuration: Configuration
  
  init(wallet: Wallet,
       payload: BatteryRechargePayload,
       batteryService: BatteryService,
       sendService: SendService,
       tonProofTokenService: TonProofTokenService,
       configuration: Configuration) {
    self.wallet = wallet
    self.payload = payload
    self.batteryService = batteryService
    self.sendService = sendService
    self.tonProofTokenService = tonProofTokenService
    self.configuration = configuration
  }
  
  func getBoc(signClosure: (TransferData) async throws -> String) async throws -> String {
    let config = try await batteryService.loadBatteryConfig(wallet: wallet)
    let batteryBalance = await getBatteryBalance(wallet: wallet)
    let rechargeMethod = await getRechargeMethod(wallet: wallet, token: payload.token)
    let rechargeMethodMaxInputAmount = await getRechargeMethodMaxInputAmount(
      rechargeMethod: rechargeMethod,
      batteryMaxInputAmount: configuration.batteryMaxInputAmount(isTestnet: wallet.isTestnet)
    )
    
    let amountDecimalNumber = NSDecimalNumber.fromBigUInt(value: payload.amount, decimals: payload.token.fractionDigits)
    
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let fundReceiver = config.fundReceiver
    let toAddress = try AnyAddress(rawAddress: fundReceiver)
    let validUntil = await sendService.getTimeoutSafely(wallet: wallet, TTL: UInt64(abs(config.messageTtl)))
    let isForceRelayer = isForceRelayer(
      batteryBalance: batteryBalance,
      rechargeMethod: rechargeMethod,
      amount: amountDecimalNumber
    )
    
    let batteryPayload = createBatteryPayload(
      recipientAddress: payload.recipient?.recipientAddress.address, promocode: payload.promocode
    )
    
    let payloads = try createPayloads(toAddress: toAddress,
                                      validUntil: validUntil,
                                      batteryPayload: batteryPayload)
    
    let transferData = TransferData(
      transfer: .tonConnect(
        TransferData.TonConnect(
          payloads: payloads,
          sender: try wallet.address
        )
      ),
      wallet: wallet,
      messageType: .ext,
      seqno: seqno,
      timeout: validUntil
    )
    
    return try await signClosure(transferData)
  }
  
  private func createPayloads(toAddress: KeeperCore.AnyAddress, 
                              validUntil: UInt64,
                              batteryPayload: Cell?) throws -> [TransferData.TonConnect.Payload] {
    switch payload.token {
    case .ton:
      try createTonPayloads(toAddress: toAddress,
                            validUntil: validUntil,
                            batteryPayload: batteryPayload)
    case .jetton(let jettonItem):
      try createJettonPayloads(jettonItem: jettonItem,
                               toAddress: toAddress,
                               validUntil: validUntil,
                               batteryPayload: batteryPayload)
    }
  }
  
  private func createTonPayloads(toAddress: KeeperCore.AnyAddress,
                                 validUntil: UInt64,
                                 batteryPayload: Cell?) throws -> [TransferData.TonConnect.Payload] {
    let param = SendTransactionParam(
      messages: [
        SendTransactionParam.Message(
          address: toAddress,
          amount: Int64(payload.amount),
          stateInit: nil,
          payload: try? batteryPayload?.toBoc().base64EncodedString()
        )
      ],
      validUntil: TimeInterval(validUntil),
      from: try wallet.address
    )
    
    return param.messages.map { message in
      TransferData.TonConnect.Payload(
        value: BigInt(integerLiteral: message.amount),
        recipientAddress: message.address,
        stateInit: message.stateInit,
        payload: message.payload
      )
    }
  }
  
  private func createJettonPayloads(jettonItem: JettonItem,
                                    toAddress: KeeperCore.AnyAddress,
                                    validUntil: UInt64,
                                    batteryPayload: Cell?) throws -> [TransferData.TonConnect.Payload] {
    
    let jettonTransferData = JettonTransferData(
      queryId: UInt64(UnsignedTransferBuilder.newWalletQueryId()),
      amount: payload.amount,
      toAddress: toAddress.address,
      responseAddress: try wallet.address,
      forwardAmount: BigUInt(stringLiteral: "1"),
      forwardPayload: batteryPayload,
      customPayload: nil
    )
    
    let param = SendTransactionParam(
      messages: [
        SendTransactionParam.Message(
          address: .address(jettonItem.walletAddress),
          amount: 100000000,
          stateInit: nil,
          payload: try Builder().store(jettonTransferData).endCell().toBoc().base64EncodedString()
        )
      ],
      validUntil: TimeInterval(validUntil),
      from: try wallet.address
    )
    
    return param.messages.map { message in
      TransferData.TonConnect.Payload(
        value: BigInt(integerLiteral: message.amount),
        recipientAddress: message.address,
        stateInit: message.stateInit,
        payload: message.payload
      )
    }
  }
  
  private func getRechargeMethodMaxInputAmount(rechargeMethod: BatteryRechargeMethod?,
                                               batteryMaxInputAmount: NSDecimalNumber) -> NSDecimalNumber {
    guard let rechargeMethod else { return 0 }
    return batteryMaxInputAmount.dividing(by: rechargeMethod.rate)
  }
  
  private func getBatteryBalance(wallet: Wallet) async -> BatteryBalance {
    do {
      let tonProof = try tonProofTokenService.getWalletToken(wallet)
      let batteryBalance = try await batteryService.loadBatteryBalance(wallet: wallet, tonProofToken: tonProof)
      return batteryBalance
    } catch {
      return BatteryBalance.empty
    }
  }
  
  private func getRechargeMethod(wallet: Wallet, token: Token) async -> BatteryRechargeMethod? {
    let methods = await {
      do {
        return try await batteryService.loadRechargeMethods(wallet: wallet, includeRechargeOnly: true)
      } catch {
        return []
      }
    }()
    return methods.first(where: { method in
      switch token {
      case .ton:
        method.token == .ton
      case .jetton(let jettonItem):
        method.jettonMasterAddress == jettonItem.jettonInfo.address
      }
    })
  }
  
  private func isForceRelayer(batteryBalance: BatteryBalance,
                              rechargeMethod: BatteryRechargeMethod?,
                              amount: NSDecimalNumber) -> Bool {
    switch payload.token {
    case .ton:
      return false
    case .jetton:
      if batteryBalance.balanceDecimalNumber.compare(0) == .orderedDescending {
        return true
      } else if let minBootstrapValue = rechargeMethod?.minBootstrapValue {
        return minBootstrapValue.compare(amount) == .orderedAscending
      } else {
        return false
      }
    }
  }
  
  private func createBatteryPayload(recipientAddress: Address? = nil,
                                    promocode: String? = nil) -> Cell? {
    do {
      let builder = Builder()
      try builder.store(uint: Int32.batteryPayloadOpcode, bits: 32)
      if let recipientAddress {
        try builder.store(bit: true)
        try builder.store(recipientAddress)
      } else {
        try builder.store(bit: false)
      }
      if let promocode, !promocode.isEmpty, let promocodeData = promocode.data(using: .utf8) {
        try builder.store(bit: true)
        try builder.store(data: promocodeData)
      } else {
        try builder.store(bit: false)
      }
      return try builder.endCell()
    } catch {
      return nil
    }
  }
}

private extension Int32 {
  static let batteryPayloadOpcode = 0xb7b2515f
}
