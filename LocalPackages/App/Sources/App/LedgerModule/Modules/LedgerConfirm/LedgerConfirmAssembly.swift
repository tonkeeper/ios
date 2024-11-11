import Foundation
import TKCore
import KeeperCore

struct LedgerConfirmAssembly {
  private init() {}
  static func module(transferData: TransferData,
                     wallet: Wallet,
                     ledgerDevice: Wallet.LedgerDevice,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<LedgerConfirmViewController, LedgerConfirmModuleOutput, Void> {
    let viewModel = LedgerConfirmViewModelImplementation(transferData: transferData, wallet: wallet, ledgerDevice: ledgerDevice)
    let viewController = LedgerConfirmViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
