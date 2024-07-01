import Foundation
import TonSwift

public struct Transaction {
  let destination: Address
  let sendMode: Int
  let seqno: Int
  let timeout: Int
  let bounceable: Bool
  let coins: Coins
  let stateInit: StateInit?
  let payload: TonPayloadFormat?
}
