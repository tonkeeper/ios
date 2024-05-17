import Foundation
import TonSwift
import BigInt
@testable import SignerCore

struct MockEntities {
  static var mockPublicKey: TonSwift.PublicKey {
    TonSwift.PublicKey(data: String(repeating: "0", count: 32).data(using: .utf8)!)
  }
  
  static var mockContract: WalletContract {
    WalletV4R2(publicKey: mockPublicKey.data)
  }
  
  static var mockWalletLink: WalletLink {
    WalletLink(
      network: .testnet,
      publicKey: mockPublicKey,
      contractVersion: .v4R2)
  }
  
  static var mockTransferCell: Cell {
    get throws {
      let address = Address.mock(workchain: 0, seed: "mock,seed")
      let value = BigUInt(integerLiteral: 10)
      let textPayload = "text payload"
      let internalMessage = try MessageRelaxed.internal(
        to: address,
        value: value,
        textPayload: textPayload)
      let transferData = WalletTransferData(
        seqno: 8976,
        messages: [internalMessage],
        sendMode: .walletDefault(),
        timeout: 60)
      let transfer = try mockContract.createTransfer(args: transferData)
      return try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
    }
  }
}


