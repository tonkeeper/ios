import Foundation
import KeeperCore
import TonSwift
import BigInt

struct TransactionConfirmationDeeplinkBocBuilder {
  
  private let wallet: Wallet
  private let payload: TransactionConfirmationDeeplinkPayload
  private let sendService: SendService
  private let configuration: Configuration
  
  init(wallet: Wallet,
       payload: TransactionConfirmationDeeplinkPayload,
       sendService: SendService,
       configuration: Configuration) {
    self.wallet = wallet
    self.payload = payload
    self.sendService = sendService
    self.configuration = configuration
  }
  
  func getBoc(signClosure: (TransferData) async throws -> String) async throws -> String {
    let amountDecimalNumber = NSDecimalNumber.fromBigUInt(value: payload.amount, decimals: 9)
    
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let validUntil = await sendService.getTimeoutSafely(wallet: wallet)
        
    let param = SendTransactionParam(
      messages: [
        SendTransactionParam.Message(
          address: .address(payload.recipient.recipientAddress.address),
          amount: Int64(payload.amount),
          stateInit: payload.stateInit,
          payload: payload.payload
        )
      ],
      validUntil: TimeInterval(validUntil),
      from: try wallet.address
    )
    
    let payloads = param.messages.map { message in
      TransferData.TonConnect.Payload(
        value: BigInt(integerLiteral: message.amount),
        recipientAddress: message.address,
        stateInit: message.stateInit,
        payload: message.payload
      )
    }
    
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
}
