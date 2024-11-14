import Foundation
import TonSwift
import BigInt

public struct StakeTransferBuilder {
  private init() {}
  
  public static func createWhalesDepositWalletTransfer(wallet: Wallet,
                                                       seqno: UInt64,
                                                       queryId: BigUInt,
                                                       poolAddress: Address,
                                                       amount: BigUInt,
                                                       isMax: Bool,
                                                       forwardAmount: BigUInt,
                                                       bounce: Bool = true,
                                                       timeout: UInt64?,
                                                       messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try StakeDepositMessage.whalesInternalMessage(
          queryId: queryId,
          poolAddress: poolAddress,
          amount: amount,
          forwardAmount: forwardAmount,
          bounce: bounce
        )
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
  
  public static func createLiquidTFDepositWalletTransfer(wallet: Wallet,
                                                         seqno: UInt64,
                                                         queryId: BigUInt,
                                                         poolAddress: Address,
                                                         amount: BigUInt,
                                                         isMax: Bool,
                                                         bounce: Bool = true,
                                                         timeout: UInt64?,
                                                         messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try StakeDepositMessage.liquidTFInternalMessage(
          queryId: queryId,
          poolAddress: poolAddress,
          amount: amount,
          bounce: bounce
        )
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
  
  public static func createTFDepositWalletTransfer(wallet: Wallet,
                                                   seqno: UInt64,
                                                   queryId: BigUInt,
                                                   poolAddress: Address,
                                                   amount: BigUInt,
                                                   isMax: Bool,
                                                   bounce: Bool = true,
                                                   timeout: UInt64?,
                                                   messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try StakeDepositMessage.tfInternalMessage(
          queryId: queryId,
          poolAddress: poolAddress,
          amount: amount,
          bounce: bounce
        )
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
  
  public static func createWhalesWithdrawWalletTransfer(wallet: Wallet,
                                                        seqno: UInt64,
                                                        queryId: BigUInt,
                                                        poolAddress: Address,
                                                        amount: BigUInt,
                                                        withdrawFee: BigUInt,
                                                        forwardAmount: BigUInt,
                                                        bounce: Bool = true,
                                                        timeout: UInt64?,
                                                        messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try StakeWithdrawMessage.whalesInternalMessage(
          queryId: queryId,
          poolAddress: poolAddress,
          amount: amount,
          withdrawFee: withdrawFee,
          forwardAmount: forwardAmount,
          bounce: bounce
        )
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
  
  public static func createLiquidTFWithdrawWalletTransfer(wallet: Wallet,
                                                          seqno: UInt64,
                                                          queryId: BigUInt,
                                                          jettonWalletAddress: Address,
                                                          amount: BigUInt,
                                                          withdrawFee: BigUInt,
                                                          bounce: Bool = true,
                                                          timeout: UInt64?,
                                                          messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try StakeWithdrawMessage.liquidTFInternalMessage(
          queryId: queryId,
          amount: amount,
          withdrawFee: withdrawFee,
          jettonWalletAddress: jettonWalletAddress,
          responseAddress: wallet.address,
          bounce: bounce
        )
        return [internalMessage]
      },
      timeout: timeout,
      messageType: messageType
    )
  }
  
  public static func tfWithdrawWalletTransfer(wallet: Wallet,
                                              seqno: UInt64,
                                              queryId: BigUInt,
                                              poolAddress: Address,
                                              forwardAmount: BigUInt,
                                              bounce: Bool = true,
                                              timeout: UInt64?,
                                              messageType: MessageType) throws -> WalletTransfer {
    try WalletTransferBuilder.buildWalletTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { sender in
        let internalMessage = try StakeDepositMessage.tfInternalMessage(
          queryId: queryId,
          poolAddress: poolAddress,
          amount: forwardAmount,
          bounce: bounce,
          withdrawal: true
        )
        return [internalMessage]     
      },
      timeout: timeout,
      messageType: messageType
    )
  }
}
