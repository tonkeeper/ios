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
  
  func getBoc(signClosure: (TransferMessageBuilder) async throws -> String) async throws -> String {
    let config = try await batteryService.loadBatteryConfig(wallet: wallet)
    let batteryBalance = await getBatteryBalance(wallet: wallet)
    let rechargeMethod = await getRechargeMethod(wallet: wallet, token: payload.token)
    let rechargeMethodMaxInputAmount = await getRechargeMethodMaxInputAmount(
      rechargeMethod: rechargeMethod,
      batteryMaxInputAmount: configuration.batteryMaxInputAmount
    )
    
    let amountDecimalNumber = NSDecimalNumber.fromBigUInt(value: payload.amount, decimals: payload.token.fractionDigits)
    if amountDecimalNumber.compare(rechargeMethodMaxInputAmount) == .orderedDescending {
      print("Error")
    }
    
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let fundReceiver = config.fundReceiver
    let toAddress = try AnyAddress(rawAddress: fundReceiver)
    let validUntil = await sendService.getTimeoutSafely(wallet: wallet, TTL: UInt64(abs(config.messageTtl)))
    let isForceRelayer = isForceRelayer(
      batteryBalance: batteryBalance,
      rechargeMethod: rechargeMethod,
      amount: amountDecimalNumber
    )
    
    let payloads = try createPayloads(toAddress: toAddress, validUntil: validUntil)
    
    return try await TransferMessageBuilder(
      transferData: .tonConnect(
        TransferData.TonConnect(
          seqno: seqno,
          payloads: payloads,
          sender: try wallet.address,
          timeout: validUntil
        )
      )
    ).createBoc(signClosure: signClosure)
  }
  
  private func createPayloads(toAddress: KeeperCore.AnyAddress, validUntil: UInt64) throws -> [TransferData.TonConnect.Payload] {
    switch payload.token {
    case .ton:
      try createTonPayloads(toAddress: toAddress, validUntil: validUntil)
    case .jetton(let jettonItem):
      try createJettonPayloads(jettonItem: jettonItem,
                               toAddress: toAddress,
                               validUntil: validUntil)
    }
  }
  
  private func createTonPayloads(toAddress: KeeperCore.AnyAddress, validUntil: UInt64) throws -> [TransferData.TonConnect.Payload] {
    let param = SendTransactionParam(
      messages: [
        SendTransactionParam.Message(
          address: toAddress,
          amount: Int64(payload.amount),
          stateInit: nil,
          payload: nil
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
                                    validUntil: UInt64) throws -> [TransferData.TonConnect.Payload] {
    
    let jettonTransferData = JettonTransferData(
      queryId: UInt64(TransferMessageBuilder.newWalletQueryId()),
      amount: payload.amount,
      toAddress: toAddress.address,
      responseAddress: try wallet.address,
      forwardAmount: BigUInt(stringLiteral: "1"),
      forwardPayload: nil,
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
    guard let rechargeMethod,
          let rate = rechargeMethod.rateDecimalNumber else { return 0 }
    return batteryMaxInputAmount.dividing(by: rate)
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
      } else if let minBootstrapValue = rechargeMethod?.minBootstrapValueDecimalNumber {
        return minBootstrapValue.compare(amount) == .orderedAscending
      } else {
        return false
      }
    }
  }
}
