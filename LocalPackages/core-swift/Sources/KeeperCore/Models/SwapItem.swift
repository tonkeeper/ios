import Foundation
import BigInt

public struct SwapItem {
  let sendToken: Token
  let sendAmount: BigUInt

  let receiveToken: Token
  let receiveAmount: BigUInt // mimimum

  public init(sendToken: Token, sendAmount: BigUInt, receiveToken: Token, receiveAmount: BigUInt) {
    self.sendToken = sendToken
    self.sendAmount = sendAmount
    self.receiveToken = receiveToken
    self.receiveAmount = receiveAmount
  }
}
