import Foundation
import TonSwift
import BigInt

public struct UnsignedTransferBuilder {
  public let transferData: TransferData
  
  public let queryId: BigUInt
  
  public init(transferData: TransferData) {
    self.transferData = transferData
    self.queryId = UnsignedTransferBuilder.newWalletQueryId()
  }
  
  public static func newWalletQueryId() -> BigUInt {
    let tonkeeperSignature: [UInt8] = [0x54, 0x6d, 0xe4, 0xef]
    
    var randomBytes = [UInt8](repeating: 0, count: 4)
    arc4random_buf(&randomBytes, 4)

    let hexString = Data(tonkeeperSignature + randomBytes).hexString()
    return BigUInt(hexString, radix: 16) ?? BigUInt(0)
  }
  
  public func createUnsignedWalletTransfer(wallet: Wallet) async throws -> WalletTransfer {
    switch transferData.transfer {
    case .ton(let ton):
      return try TonTransferBuilder.createWalletTransfer(
        wallet: wallet,
        seqno: transferData.seqno,
        value: ton.amount,
        isMax: ton.isMax,
        recipientAddress: ton.recipient,
        isBounceable: ton.isBouncable,
        comment: ton.comment,
        timeout: transferData.timeout,
        messageType: transferData.messageType
      )
    case .jetton(let jetton):
      return try JettonTransferBuilder.createWalletTransfer(
        wallet: wallet,
        seqno: transferData.seqno,
        tokenAddress: jetton.jettonAddress,
        value: jetton.amount,
        recipientAddress: jetton.recipient,
        responseAddress: jetton.responseAddress,
        isBounceable: jetton.isBouncable,
        comment: jetton.comment,
        timeout: transferData.timeout,
        customPayload: jetton.customPayload,
        stateInit: jetton.stateInit,
        messageType: transferData.messageType
      )
    case .nft(let nft):
      return try NFTTransferBuilder.createWalletTransfer(
        wallet: wallet,
        seqno: transferData.seqno,
        nftAddress: nft.nftAddress,
        recipientAddress: nft.recipient,
        responseAddress: nft.responseAddress,
        isBounceable: nft.isBounceable,
        transferAmount: nft.transferAmount,
        timeout: transferData.timeout,
        forwardPayload: nft.forwardPayload,
        messageType: transferData.messageType
      )
    case .swap(let swap):
      fatalError()
    case .tonConnect(let tonConnect):
      return try SignRawTransferBuilder.createWalletTransfer(
        wallet: wallet,
        seqno: transferData.seqno,
        payloads: tonConnect.payloads.map {
          SignRawTransferBuilder.Payload(
            value: $0.value,
            recipientAddress: $0.recipientAddress,
            stateInit: $0.stateInit,
            payload: $0.payload
          )
        },
        sender: tonConnect.sender,
        timeout: transferData.timeout,
        messageType: transferData.messageType
      )
    case .changeDNSRecord(let changeDNSRecord):
      switch changeDNSRecord {
      case .link(let linkDNS):
        return try ChangeDNSRecordTransferBuilder.createLinkDNSWalletTransfer(
          wallet: wallet,
          seqno: transferData.seqno,
          nftAddress: linkDNS.nftAddress,
          linkAddress: linkDNS.linkAddress,
          linkAmount: linkDNS.linkAmount,
          timeout: transferData.timeout,
          messageType: transferData.messageType
        )
      case .renew(let renewDNS):
        return try ChangeDNSRecordTransferBuilder.createRenewDNSWalletTransfer(
          wallet: wallet,
          seqno: transferData.seqno,
          nftAddress: renewDNS.nftAddress,
          linkAmount: renewDNS.linkAmount,
          timeout: transferData.timeout,
          messageType: transferData.messageType
        )
      }
    case .stake(let stake):
      switch stake {
      case .deposit(let stakeDeposit):
        switch stakeDeposit.pool.implementation.type {
        case .liquidTF:
          return try StakeTransferBuilder.createLiquidTFDepositWalletTransfer(
            wallet: wallet,
            seqno: transferData.seqno,
            queryId: UnsignedTransferBuilder.newWalletQueryId(),
            poolAddress: stakeDeposit.pool.address,
            amount: stakeDeposit.amount,
            isMax: stakeDeposit.isMax,
            bounce: stakeDeposit.isBouncable,
            timeout: transferData.timeout,
            messageType: transferData.messageType
          )
        case .whales:
          return try StakeTransferBuilder.createWhalesDepositWalletTransfer(
            wallet: wallet,
            seqno: transferData.seqno,
            queryId: UnsignedTransferBuilder.newWalletQueryId(),
            poolAddress: stakeDeposit.pool.address,
            amount: stakeDeposit.amount,
            isMax: stakeDeposit.isMax,
            forwardAmount: 100_000,
            bounce: stakeDeposit.isBouncable,
            timeout: transferData.timeout,
            messageType: transferData.messageType
          )
        case .tf:
          return try StakeTransferBuilder.createTFDepositWalletTransfer(
            wallet: wallet,
            seqno: transferData.seqno,
            queryId: UnsignedTransferBuilder.newWalletQueryId(),
            poolAddress: stakeDeposit.pool.address,
            amount: stakeDeposit.amount,
            isMax: stakeDeposit.isMax,
            bounce: stakeDeposit.isBouncable,
            timeout: transferData.timeout,
            messageType: transferData.messageType
          )
        }
      case .withdraw(let stakeWithdraw):
        switch stakeWithdraw.pool.implementation.type {
        case .liquidTF:
          return try await StakeTransferBuilder.createLiquidTFWithdrawWalletTransfer(
            wallet: wallet,
            seqno: transferData.seqno,
            queryId: UnsignedTransferBuilder.newWalletQueryId(),
            jettonWalletAddress: stakeWithdraw.jettonWalletAddress(wallet, stakeWithdraw.pool.liquidJettonMaster),
            amount: stakeWithdraw.amount,
            withdrawFee: stakeWithdraw.pool.implementation.withdrawalFee,
            bounce: stakeWithdraw.isBouncable,
            timeout: transferData.timeout,
            messageType: transferData.messageType
          )
        case .whales:
          return try StakeTransferBuilder.createWhalesWithdrawWalletTransfer(
            wallet: wallet,
            seqno: transferData.seqno,
            queryId: UnsignedTransferBuilder.newWalletQueryId(),
            poolAddress: stakeWithdraw.pool.address,
            amount: stakeWithdraw.amount,
            withdrawFee: stakeWithdraw.pool.implementation.withdrawalFee,
            forwardAmount: 100_000,
            bounce: stakeWithdraw.isBouncable,
            timeout: transferData.timeout,
            messageType: transferData.messageType
          )
        case .tf:
          return try StakeTransferBuilder.tfWithdrawWalletTransfer(
            wallet: wallet,
            seqno: transferData.seqno,
            queryId: UnsignedTransferBuilder.newWalletQueryId(),
            poolAddress: stakeWithdraw.pool.address,
            forwardAmount: 1_000_000_000,
            bounce: stakeWithdraw.isBouncable,
            timeout: transferData.timeout,
            messageType: transferData.messageType
          )
        }
      }
    }
  }
}
