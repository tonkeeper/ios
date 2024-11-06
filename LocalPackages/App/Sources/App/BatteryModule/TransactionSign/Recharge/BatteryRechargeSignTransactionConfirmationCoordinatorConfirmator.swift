import UIKit
import KeeperCore
import TonSwift

struct BatteryRechargeSignTransactionConfirmationCoordinatorConfirmator: SignTransactionConfirmationCoordinatorConfirmator {

  private let sendService: SendService
  private let bocBuilder: BatteryRechargeBocBuilder
  
  init(bocBuilder: BatteryRechargeBocBuilder,
              sendService: SendService) {
    self.bocBuilder = bocBuilder
    self.sendService = sendService
  }
  
  func confirm(wallet: Wallet, signClosure: (TransferMessageBuilder) async throws -> String?) async throws {
    let boc = try await bocBuilder.getBoc { transferMessageBuilder in
      guard let signedBoc = try await signClosure(transferMessageBuilder) else {
        throw SignTransactionConfirmationCoordinatorConfirmatorError.failedToSign
      }
      return signedBoc
    }
    do {
      try await sendService.sendTransaction(boc: boc, wallet: wallet)
    } catch {
      throw error
    }
  }
  
  func cancel(wallet: Wallet) async {}
}
