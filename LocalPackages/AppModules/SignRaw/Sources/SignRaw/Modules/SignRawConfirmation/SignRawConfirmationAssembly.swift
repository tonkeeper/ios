import Foundation
import KeeperCore
import TKCore
import TKFeatureFlags

@MainActor
public struct SignRawConfirmationAssembly {
    private init() {}
    public static func module(
        wallet: Wallet,
        mode: SignRawConfirmationMode,
        transferProvider: @escaping () async throws -> Transfer,
        resultHandler: SignRawControllerResultHandler?,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        featureFlags: TKFeatureFlags
    ) -> MVVMModule<SignRawConfirmationViewController, SignRawConfirmationModuleOutput, SignRawConfirmationModuleInput> {
        let viewModel = SignRawConfirmationViewModelImplementation(
            wallet: wallet,
            mode: mode,
            signRawController: SignRawController(
                wallet: wallet,
                transferProvider: transferProvider,
                transferService: keeperCoreMainAssembly.transferAssembly.transferService(),
                sendService: keeperCoreMainAssembly.servicesAssembly.sendService(),
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
                balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
                nftManagmentStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet),
                accountEventMapper: AccountEventMapper(
                    dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
                    amountMapper: PlainAccountEventAmountMapper(amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter)
                ),
                accountEventModelMapper: AccountEventModelMapper(
                    accountEventModelActionContentProvider: SignRawAccountEventActionContentProvider()
                ),
                amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
            ),
            fundsValidator: keeperCoreMainAssembly.loadersAssembly.insufficientFundsValidator(),
            configurationAssembly: keeperCoreMainAssembly.configurationAssembly
        )
        let viewController = SignRawConfirmationViewController(viewModel: viewModel)

        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
