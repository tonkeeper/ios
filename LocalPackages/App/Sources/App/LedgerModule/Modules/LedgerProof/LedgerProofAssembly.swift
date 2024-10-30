import Foundation
import TKCore
import KeeperCore
import TonTransport

struct LedgerProofParameters {
  public let domain: String
  public let timestamp: UInt64
  public let payload: String
}

struct LedgerProofAssembly {
  private init() {}
  static func module(proofParameters: LedgerProofParameters, wallet: Wallet, ledgerDevice: Wallet.LedgerDevice, coreAssembly: TKCore.CoreAssembly) -> MVVMModule<LedgerProofViewController, LedgerProofModuleOutput, Void> {
    let viewModel = LedgerProofViewModelImplementation(proofParameters: proofParameters, wallet: wallet, ledgerDevice: ledgerDevice)
    let viewController = LedgerProofViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
