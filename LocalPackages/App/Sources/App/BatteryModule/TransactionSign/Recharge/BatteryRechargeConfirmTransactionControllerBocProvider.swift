import Foundation
import KeeperCore
import TonSwift

final class BatteryRechargeConfirmTransactionControllerBocProvider: ConfirmTransactionControllerBocProvider {

  private let bocBuilder: BatteryRechargeBocBuilder
  
  init(bocBuilder: BatteryRechargeBocBuilder) {
    self.bocBuilder = bocBuilder
  }
  
  func createBoc(wallet: Wallet, seqno: UInt64, timeout: UInt64) async throws -> String {
    return try await bocBuilder.getBoc { transferMessageBuilder in
      try await transferMessageBuilder.externalSign(wallet: wallet) { transfer in
        try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
      }
    }
  }
}
