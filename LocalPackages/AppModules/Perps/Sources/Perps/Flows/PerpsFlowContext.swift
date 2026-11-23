import Foundation

@MainActor
final class PerpsFlowContext {
    let dependencies: any PerpsDependencies
    let wallet: PerpsWalletDependencies
    let openPositionFlow: PerpsOpenPositionFlow
    let tradeRunner: PerpsTradeRunner
    let inputMemory: PerpsTradeInputMemory
    private var fundingRecoveryTask: Task<Void, Never>?

    init(
        dependencies: any PerpsDependencies,
        wallet: PerpsWalletDependencies,
        inputMemory: PerpsTradeInputMemory? = nil
    ) {
        self.dependencies = dependencies
        self.wallet = wallet
        self.inputMemory = inputMemory ?? .shared
        let openPositionFlow = PerpsOpenPositionFlow()
        self.openPositionFlow = openPositionFlow
        tradeRunner = PerpsTradeRunner(
            tradingService: wallet.tradingService,
            accountStore: wallet.accountStore,
            openPositionFlow: openPositionFlow,
            format: dependencies.format,
            track: wallet.track
        )
    }

    deinit {
        fundingRecoveryTask?.cancel()
    }

    var format: PerpsFormatting {
        dependencies.format
    }

    func startFundingRecovery() {
        if fundingRecoveryTask == nil {
            fundingRecoveryTask = Task { [recoverFunding = wallet.recoverFunding] in
                await recoverFunding()
            }
        }
    }

    func refreshFunding() {
        Task { [refreshFunding = wallet.refreshFunding] in await refreshFunding() }
    }
}
