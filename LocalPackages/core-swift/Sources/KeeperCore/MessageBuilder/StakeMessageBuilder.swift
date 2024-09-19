import Foundation
import TonSwift
import BigInt

public struct StakeMessageBuilder {
  private init() {}
  
  public static func whalesDepositMessage(wallet: Wallet,
                                          seqno: UInt64,
                                          queryId: BigUInt,
                                          poolAddress: Address,
                                          amount: BigUInt,
                                          forwardAmount: BigUInt,
                                          bounce: Bool = true,
                                          timeout: UInt64?,
                                          signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    return try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      sendMode: .walletDefault(),
      seqno: seqno,
      internalMessages: {
        sender in
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
      signClosure: signClosure
    )
  }
  
  public static func liquidTFDepositMessage(wallet: Wallet,
                                            seqno: UInt64,
                                            queryId: BigUInt,
                                            poolAddress: Address,
                                            amount: BigUInt,
                                            bounce: Bool = true,
                                            timeout: UInt64?,
                                            signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    return try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      sendMode: .walletDefault(),
      seqno: seqno,
      internalMessages: {
        sender in
        let internalMessage = try StakeDepositMessage.liquidTFInternalMessage(
          queryId: queryId,
          poolAddress: poolAddress,
          amount: amount,
          bounce: bounce
        )
        return [internalMessage]
      },
      timeout: timeout,
      signClosure: signClosure
    )
  }
  
  public static func tfDepositMessage(wallet: Wallet,
                                      seqno: UInt64,
                                      queryId: BigUInt,
                                      poolAddress: Address,
                                      amount: BigUInt,
                                      bounce: Bool = true,
                                      timeout: UInt64?,
                                      signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    return try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      sendMode: .walletDefault(),
      seqno: seqno,
      internalMessages: {
        sender in
        let internalMessage = try StakeDepositMessage.tfInternalMessage(
          queryId: queryId,
          poolAddress: poolAddress,
          amount: amount,
          bounce: bounce
        )
        return [internalMessage]
      },
      timeout: timeout,
      signClosure: signClosure
    )
  }
  
  public static func whalesWithdrawMessage(wallet: Wallet,
                                           seqno: UInt64,
                                           queryId: BigUInt,
                                           poolAddress: Address,
                                           amount: BigUInt,
                                           withdrawFee: BigUInt,
                                           forwardAmount: BigUInt,
                                           bounce: Bool = true,
                                           timeout: UInt64?,
                                           signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    return try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      sendMode: .walletDefault(),
      seqno: seqno,
      internalMessages: {
        sender in
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
      signClosure: signClosure
    )
  }
  
  public static func liquidTFWithdrawMessage(wallet: Wallet,
                                             seqno: UInt64,
                                             queryId: BigUInt,
                                             jettonWalletAddress: Address,
                                             amount: BigUInt,
                                             withdrawFee: BigUInt,
                                             bounce: Bool = true,
                                             timeout: UInt64?,
                                             signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    return try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      sendMode: .walletDefault(),
      seqno: seqno,
      internalMessages: {
        sender in
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
      signClosure: signClosure
    )
  }
  
  public static func tfWithdrawMessage(wallet: Wallet,
                                      seqno: UInt64,
                                      queryId: BigUInt,
                                      poolAddress: Address,
                                      amount: BigUInt,
                                      bounce: Bool = true,
                                      timeout: UInt64?,
                                      signClosure: (WalletTransfer) async throws -> Data) async throws -> String {
    return try await ExternalMessageTransferBuilder.externalMessageTransfer(
      wallet: wallet,
      sender: try wallet.address,
      sendMode: .walletDefault(),
      seqno: seqno,
      internalMessages: {
        sender in
        let internalMessage = try StakeDepositMessage.tfInternalMessage(
          queryId: queryId,
          poolAddress: poolAddress,
          amount: amount,
          bounce: bounce
        )
        return [internalMessage]
      },
      timeout: timeout,
      signClosure: signClosure
    )
  }
}

