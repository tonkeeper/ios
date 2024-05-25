import Foundation
import BigInt

enum STAKING_MESSAGE_CONSTANTS {
  enum OPCODE {
    static let liquidTFDeposit: Int32 = 0x47d54391
    static let whalesDeposit: Int32 = 2077040623
    static let iquidTFBurn: Int32 =  0x595f07bc
    static let whalesWithdraw: Int = 3665837821
  }
  
  enum GAS {
    static let whalesDeposit: BigUInt = BigUInt(integerLiteral: 100_000)
    static let whalesWithdraw: BigUInt = BigUInt(integerLiteral: 100_000)
    
  }
  
  static let liquidTFAppId: Int32 = 0x000000000005b7ce
}
