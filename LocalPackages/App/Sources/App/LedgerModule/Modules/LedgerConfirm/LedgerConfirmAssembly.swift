import Foundation
import TKCore
import KeeperCore

struct LedgerConfirmAssembly {
  private init() {}
  static func module(transferMessageBuilder: TransferMessageBuilder, wallet: Wallet, ledgerDevice: Wallet.LedgerDevice, coreAssembly: TKCore.CoreAssembly) -> MVVMModule<LedgerConfirmViewController, LedgerConfirmModuleOutput, Void> {
    let viewModel = LedgerConfirmViewModelImplementation(transferMessageBuilder: transferMessageBuilder, wallet: wallet, ledgerDevice: ledgerDevice)
    let viewController = LedgerConfirmViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
