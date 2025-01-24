import Foundation
import TKCore
import KeeperCore
import Mapping

@MainActor
public struct SignRawConfirmationAssembly {
  private init() {}
  public static func module(wallet: Wallet,
                     transferProvider: @escaping () async throws -> Transfer,
                     resultHandler: SignRawControllerResultHandler?,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<SignRawConfirmationViewController, SignRawConfirmationModuleOutput, SignRawConfirmationModuleInput> {
    let viewModel = SignRawConfirmationViewModelImplementation(
      wallet: wallet,
      signRawController: SignRawController(
        wallet: wallet,
        transferProvider: transferProvider,
        transferService: keeperCoreMainAssembly.transferAssembly.transferService(),
        nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
        currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
        resultHandler: resultHandler
      ),
      signRawConfirmationMapper: SignRawConfirmationMapper(
        nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
        currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
        totalBalanceStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
        nftManagmentStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet),
        accountEventMapper: AccountEventMapper(
          dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
          amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
          amountMapper: PlainAccountEventAmountMapper(amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter)
        ),
        accountEventModelMapper: AccountEventModelMapper(
          accountEventModelActionContentProvider: SignRawAccountEventActionContentProvider()
        ),
        decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
        amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
      ),
      fundsValidator: InsufficientFundsValidator(balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
                                                 jettonBalanceResolver: keeperCoreMainAssembly.loadersAssembly.jettonBalanceResolver())
    )
    let viewController = SignRawConfirmationViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}

