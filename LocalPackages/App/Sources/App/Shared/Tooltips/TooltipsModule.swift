import KeeperCore
import TKCore
import UIKit

final class TooltipsModule {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    private(set) lazy var overrides = TooltipDataOverridesRepository(
        appStoreEnvironment: UIApplication.shared.isAppStoreEnvironment
    )

    private(set) lazy var commonDataRepository: TooltipDataRepository = TooltipDataRepositoryImplementation(
        appSettings: dependencies.coreAssembly.appSettings,
        overridesRepository: overrides
    )

    private(set) lazy var withdrawButtonRepository = WithdrawButtonTooltipRepository(
        tooltipData: commonDataRepository
    )
}

extension TooltipsModule {
    struct Dependencies {
        let keeperCoreMainAssembly: KeeperCore.MainAssembly
        let coreAssembly: TKCore.CoreAssembly

        init(
            keeperCoreMainAssembly: KeeperCore.MainAssembly,
            coreAssembly: TKCore.CoreAssembly
        ) {
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
            self.coreAssembly = coreAssembly
        }
    }
}
