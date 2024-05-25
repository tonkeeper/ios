import Foundation
import TonSwift
import BigInt

struct StakingInternalMessage {
  static func deposit(
    poolAddress: Address,
    poolImplementation: StakingPool.Implementation,
    amount: BigUInt,
    bounce: Bool = true
  ) throws -> MessageRelaxed {
    let queryId = UInt64(Date().timeIntervalSince1970)
    
    let body = Builder()
    switch poolImplementation.type {
    case .liquidTF:
      try body.store(uint: STAKING_MESSAGE_CONSTANTS.OPCODE.liquidTFDeposit, bits: 32)
      try body.store(uint: queryId, bits: 64)
      try body.store(uint: STAKING_MESSAGE_CONSTANTS.liquidTFAppId, bits: 64)
    case .whales:
      try body.store(uint: STAKING_MESSAGE_CONSTANTS.OPCODE.whalesDeposit, bits: 32)
      try body.store(uint: queryId, bits: 64)
      try body._store(varuint: STAKING_MESSAGE_CONSTANTS.GAS.whalesDeposit, limit: 16)
    case .tf:
      try body.store(uint: 0, bits: 32)
      try body.writeSnakeData(Data("d".utf8))
    }
    
    return MessageRelaxed.internal(
      to: poolAddress,
      value: amount,
      bounce: bounce,
      body: try body.asCell()
    )
  }
  
  static func withdraw(
    poolImplementation: StakingPool.Implementation,
    amount: BigUInt,
    withdrawFee: BigUInt,
    jettonWalletAddress: Address,
    responseAddress: Address,
    bounce: Bool = true
  ) throws -> MessageRelaxed {
    let queryId = UInt64(Date().timeIntervalSince1970)
    
    let body = Builder()
    switch poolImplementation.type {
    case .liquidTF:
      let customPayload = Builder()
      try customPayload.store(uint: 1, bits: 1)
      try customPayload.store(uint: 0, bits: 1)
      
      try body.store(uint: STAKING_MESSAGE_CONSTANTS.OPCODE.iquidTFBurn, bits: 32)
      try body.store(uint: queryId, bits: 64)
      try body._store(varuint: amount.magnitude, limit: 16)
      try body.store(AnyAddress.internalAddr(responseAddress))
      try body.storeMaybe(ref: customPayload.endCell())
    case .whales:
      try body.store(uint: STAKING_MESSAGE_CONSTANTS.OPCODE.whalesWithdraw, bits: 32)
      try body.store(uint: queryId, bits: 64)
      try body._store(varuint: STAKING_MESSAGE_CONSTANTS.GAS.whalesWithdraw, limit: 16)
      try body._store(varuint: amount.magnitude, limit: 16)
    case .tf:
      try body.store(uint: 0, bits: 32)
      try body.writeSnakeData(Data("w".utf8))
    }
    
    return MessageRelaxed.internal(
      to: jettonWalletAddress,
      value: withdrawFee,
      bounce: bounce,
      body: try body.asCell()
    )
  }
}

extension Builder {
  // The store(coins: Coins) method is internal, and the storeMaybe(_ object: CellCodable) method adds 1 bit in front of the object.
  // This private extension was extracted to encapsulate the logic for storing variable
  @discardableResult
  func _store(varuint v: BigUInt, limit: Int) throws -> Self {
      let maxsize = limit - 1
      if maxsize < 0 {
          throw TonError.custom("Invalid limit. Got \(limit) < 1")
      }
      if v.bitWidth > maxsize * 8 {
          throw TonError.varUIntOutOfBounds(limit: limit, actualBits: v.bitWidth)
      }
      
      let prefixSize = bitsForInt(maxsize)
      if v == 0 {
          try store(uint: 0, bits: prefixSize)
          return self
      }

      let sizeBytes = Int(ceil(Double(v.bitWidth) / 8.0))
      let sizeBits = sizeBytes * 8

      try store(uint: sizeBytes, bits: prefixSize)
      try store(uint: v, bits: sizeBits)
      
      return self
  }
}


