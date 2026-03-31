import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit

struct PaymentMethodModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
}

extension PaymentMethodModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly

        init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
        }
    }
}
