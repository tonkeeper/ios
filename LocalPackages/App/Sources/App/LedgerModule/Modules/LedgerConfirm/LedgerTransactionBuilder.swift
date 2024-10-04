import Foundation
import TonTransport
import KeeperCore
import TonSwift
import BigInt

public struct LedgerTransactionBuilder {
  enum Error: Swift.Error {
    case unsupportedTransaction
  }
  
  let transferMessageBuilder: TransferMessageBuilder
  let wallet: Wallet
  let tonTransport: TonTransport
  let accountPath: AccountPath
  
  public init(wallet: Wallet, transferMessageBuilder: TransferMessageBuilder, tonTransport: TonTransport, accountPath: AccountPath) {
    self.wallet = wallet
    self.transferMessageBuilder = transferMessageBuilder
    self.tonTransport = tonTransport
    self.accountPath = accountPath
  }
  
  private func build() throws -> Transaction {
    switch self.transferMessageBuilder.transferData {
    case .ton(let ton):
      let payload: TonPayloadFormat?
      if let comment = ton.comment {
        payload = .comment(comment)
      } else {
        payload = nil
      }
      return Transaction(
        destination: ton.recipient,
        sendMode: ton.isMax ? .sendMaxTon() : .walletDefault(),
        seqno: ton.seqno,
        timeout: ton.timeout,
        bounceable: ton.isBouncable,
        coins: Coins(rawValue: ton.amount)!,
        stateInit: nil,
        payload: payload
      )
    case .jetton(let jetton):
      var commentCell: Cell?
      if let comment = jetton.comment {
        commentCell = try Builder().store(int: 0, bits: 32).writeSnakeData(Data(comment.utf8)).endCell()
      }
      return Transaction(
        destination: jetton.jettonAddress,
        sendMode: .walletDefault(),
        seqno: jetton.seqno,
        timeout: jetton.timeout,
        bounceable: jetton.isBouncable,
        coins: Coins(rawValue: BigUInt(stringLiteral: "64000000"))!,
        stateInit: nil,
        payload: .jettonTransfer(
          TonPayloadFormat.JettonTransfer(
            queryId: transferMessageBuilder.queryId,
            coins: Coins(rawValue: jetton.amount)!,
            receiverAddress: jetton.recipient,
            excessesAddress: try wallet.address,
            customPayload: nil,
            forwardAmount: Coins(rawValue: BigUInt(stringLiteral: "1"))!,
            forwardPayload: commentCell
          )
        )
      )
    case .nft(let nft):
      return Transaction(
        destination: nft.nftAddress,
        sendMode: .walletDefault(),
        seqno: nft.seqno,
        timeout: nft.timeout,
        bounceable: nft.isBounceable,
        coins: Coins(rawValue: nft.transferAmount)!,
        stateInit: nil,
        payload: .nftTransfer(
          TonPayloadFormat.NftTransfer(
            queryId: transferMessageBuilder.queryId,
            newOwnerAddress: nft.recipient,
            excessesAddress: try wallet.address,
            customPayload: nil,
            forwardAmount: Coins(rawValue: BigUInt(stringLiteral: "1"))!,
            forwardPayload: nft.forwardPayload
          )
        )
      )
    default:
      throw Error.unsupportedTransaction
    }
  }
  
  public func signTransaction() async throws -> String {
    let sender = try wallet.address
    let contract = try wallet.contract
    
    let transaction = try build()
    let transferCell = try await tonTransport.signTransaction(path: accountPath, transaction: transaction)
    
    let externalMessage = Message.external(to: sender,
                                           stateInit: transaction.seqno == 0 ? contract.stateInit : nil,
                                           body: transferCell)
    let cell = try Builder().store(externalMessage).endCell()
    return try cell.toBoc().base64EncodedString()
  }
}
