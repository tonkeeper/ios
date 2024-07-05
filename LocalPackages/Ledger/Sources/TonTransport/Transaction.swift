import Foundation
import TonSwift

public struct Transaction {
  public let destination: Address
  public let sendMode: SendMode
  public let seqno: UInt64
  public let timeout: UInt64?
  public let bounceable: Bool
  public let coins: Coins
  public let stateInit: StateInit?
  public let payload: TonPayloadFormat?
  
  public init(destination: Address,
              sendMode: SendMode,
              seqno: UInt64,
              timeout: UInt64?,
              bounceable: Bool,
              coins: Coins,
              stateInit: StateInit?,
              payload: TonPayloadFormat?) {
    self.destination = destination
    self.sendMode = sendMode
    self.seqno = seqno
    self.timeout = timeout
    self.bounceable = bounceable
    self.coins = coins
    self.stateInit = stateInit
    self.payload = payload
  }
}
