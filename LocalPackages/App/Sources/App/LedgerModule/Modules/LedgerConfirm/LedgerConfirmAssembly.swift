import Foundation
import TKCore
import KeeperCore
import TonTransport

struct LedgerConfirmAssembly {
  private init() {}
  static func module(transaction: Transaction, 
                     wallet: Wallet,
                     ledgerDevice: Wallet.LedgerDevice,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<LedgerConfirmViewController, LedgerConfirmModuleOutput, Void> {
    let viewModel = LedgerConfirmViewModelImplementation(
      transaction: transaction,
      wallet: wallet,
      ledgerDevice: ledgerDevice,
      bleTransport: coreAssembly.ledgerAssembly.bleTransport
    )
    let viewController = LedgerConfirmViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
