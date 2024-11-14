import Foundation
import TonSwift
import BigInt

public struct SignRawTransferBuilder {
  
  public struct Payload {
    let value: BigInt
    let recipientAddress: AnyAddress
    let stateInit: String?
    let payload: String?
    
    public init(value: BigInt,
                recipientAddress: AnyAddress,
                stateInit: String?,
                payload: String?) {
      self.value = value
      self.recipientAddress = recipientAddress
      self.stateInit = stateInit
      self.payload = payload
    }
  }
  
  private init() {}
  public static func createWalletTransfer(wallet: Wallet,
                                          seqno: UInt64,
                                          payloads: [Payload],
                                          sender: Address? = nil,
                                          timeout: UInt64?,
                                          messageType: MessageType) throws -> WalletTransfer {
    let messages = try payloads.map { payload in
      var stateInit: StateInit?
      if let stateInitString = payload.stateInit {
        stateInit = try StateInit.loadFrom(
          slice: try Cell
            .fromBase64(src: stateInitString)
            .toSlice()
        )
      }
      var body: Cell = .empty
      if let messagePayload = payload.payload {
        body = try Cell.fromBase64(src: messagePayload.fixBase64())
      }
      return MessageRelaxed.internal(
        to: payload.recipientAddress.address,
        value: payload.value.magnitude,
        bounce: {
          switch payload.recipientAddress {
          case .address: return true
          case .friendlyAddress(let friendlyAddress): return friendlyAddress.isBounceable
          }
        }(),
        stateInit: stateInit,
        body: body)
    }
    
    return try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        messages
      },
      timeout: timeout,
      messageType: messageType
    )
  }
}
