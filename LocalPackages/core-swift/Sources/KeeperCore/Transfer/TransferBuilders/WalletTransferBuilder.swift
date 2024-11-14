import Foundation
import TonSwift

public struct WalletTransferBuilder {
  private init() {}
  
  public static func buildWalletTransfer(wallet: Wallet,
                                         sender: Address,
                                         sendMode: SendMode = .walletDefault(),
                                         seqno: UInt64,
                                         internalMessages: (_ sender: Address) throws -> [MessageRelaxed],
                                         timeout: UInt64?,
                                         messageType: MessageType) throws -> WalletTransfer {
    let internalMessages = try internalMessages(sender)
    let transferData = WalletTransferData(
      seqno: seqno,
      messages: internalMessages,
      sendMode: sendMode,
      timeout: timeout)
    let contract = try wallet.contract
    let transfer = try contract.createTransfer(args: transferData, messageType: messageType)
    
    return transfer
  }
}
