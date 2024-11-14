import Foundation
import KeeperCore
import TonSwift

final class BatteryRechargeConfirmTransactionControllerBocProvider: ConfirmTransactionControllerBocProvider {

  private let bocBuilder: BatteryRechargeBocBuilder
  
  init(bocBuilder: BatteryRechargeBocBuilder) {
    self.bocBuilder = bocBuilder
  }
  
  func createBoc(wallet: Wallet, seqno: UInt64, timeout: UInt64) async throws -> String {
    return try await bocBuilder.getBoc { transferData in
      let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
        .createUnsignedWalletTransfer(
          wallet: wallet
        )
      let signed = try TransferSigner.signWalletTransfer(
        walletTransfer,
        wallet: wallet,
        seqno: transferData.seqno,
        signer: WalletTransferEmptyKeySigner()
      )
      
      return try signed.toBoc().hexString()
    }
  }
}
