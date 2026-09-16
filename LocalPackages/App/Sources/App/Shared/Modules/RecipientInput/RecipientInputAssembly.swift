import KeeperCore
import TKCore

struct RecipientInputAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> RecipientInputViewModel {
        RecipientInputViewModel(
            wallet: wallet,
            recipientResolver: keeperCoreMainAssembly.loadersAssembly.recipientResolver()
        )
    }
}
