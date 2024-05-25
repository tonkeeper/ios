import Foundation
import TonSwift
import BigInt

public struct StakingMessageBuilder {
  public static func deposit(
    wallet: Wallet,
    seqno: UInt64,
    poolAddress: Address,
    poolImplementation: StakingPool.Implementation,
    amount: BigUInt,
    timeout: UInt64,
    signClosure: (WalletTransfer) async throws -> Data
  ) async throws -> String {
    let internalMessage = try StakingInternalMessage.deposit(
      poolAddress: poolAddress,
      poolImplementation: poolImplementation,
      amount: amount
    )
    let message = try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { _ in
        return [internalMessage]
      },
      timeout: timeout,
      signClosure: signClosure
    )
    
    return message
  }
  
  public static func withdraw(
    poolImplementation: StakingPool.Implementation,
    wallet: Wallet,
    seqno: UInt64,
    jettonWalletAddress: Address,
    amount: BigUInt,
    withdrawFee: BigUInt,
    signClosure: (WalletTransfer) async throws -> Data
  ) async throws -> String {
    let internalMessage = try StakingInternalMessage.withdraw(
      poolImplementation: poolImplementation,
      amount: amount,
      withdrawFee: withdrawFee,
      jettonWalletAddress: jettonWalletAddress,
      responseAddress: wallet.address
    )
    
    let message = try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      seqno: seqno,
      internalMessages: { _ in
        return [internalMessage]
      },
      timeout: nil,
      signClosure: signClosure
    )
    
    return message
  }
}
