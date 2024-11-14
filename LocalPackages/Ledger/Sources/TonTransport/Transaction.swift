import Foundation
import TonSwift

public struct Transaction {
  public let destination: Address
  public let sendMode: SendMode
  public let seqno: UInt64
  public let timeout: UInt64
  public let bounceable: Bool
  public let coins: Coins
  public let stateInit: StateInit?
  public let payload: TonPayloadFormat?
  
  public init(destination: Address,
              sendMode: SendMode,
              seqno: UInt64,
              timeout: UInt64,
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
  
  public static func from(transfer: WalletTransfer) throws -> [Transaction] {
    let slice = try transfer.signingMessage.endCell().toSlice()
    try slice.skip(32)
    let timeout = try slice.loadUint(bits: 32)
    let seqno = try slice.loadUint(bits: 32)
    try slice.skip(8)
    
    var transactionItems = [Transaction]()
    
    while slice.remainingRefs > 0 {
      let sendMode = try slice.loadUint(bits: 8)
      let messageCell = try slice.loadRef()
      let slice = try messageCell.toSlice()
      let message: MessageRelaxed = try slice.loadType()
      
      switch message.info {
      case .internalInfo(let info):
        transactionItems.append(
          Transaction(
            destination: info.dest,
            sendMode: SendMode(rawValue: UInt8(sendMode)) ?? .walletDefault(),
            seqno: seqno,
            timeout: timeout,
            bounceable: info.bounce,
            coins: info.value.coins,
            stateInit: message.stateInit,
            payload: message.body.bits.length > 0 || message.body.refs.count > 0 ? try TonPayloadFormat.from(cell: message.body) : nil
          )
        )
      case .externalOutInfo:
        continue
      }
    }
    
    return transactionItems
  }
}
