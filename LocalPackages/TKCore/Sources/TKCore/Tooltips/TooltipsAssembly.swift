import Foundation
import KeeperCore
import TKFeatureFlags

public final class TooltipsAssembly {
    public struct Dependencies {
        public let appSettings: AppSettings
        public let appStoreEnvironment: Bool

        public init(
            appSettings: AppSettings,
            appStoreEnvironment: Bool
        ) {
            self.appSettings = appSettings
            self.appStoreEnvironment = appStoreEnvironment
        }
    }

    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public private(set) lazy var overrides = TooltipDataOverridesRepository(
        appStoreEnvironment: dependencies.appStoreEnvironment
    )

    public private(set) lazy var commonDataRepository: TooltipDataRepository = TooltipDataRepositoryImplementation(
        appSettings: dependencies.appSettings,
        overridesRepository: overrides
    )

    public private(set) lazy var withdrawButtonRepository = WithdrawButtonTooltipRepository(
        tooltipData: commonDataRepository
    )

    public private(set) lazy var newHistoryEntryPointRepository = NewHistoryEntryPointTooltipRepository()

    public private(set) lazy var tradeTabRepository = TradeTabTooltipRepository()

    public private(set) lazy var favoriteRepository = FavoriteTooltipRepository()

    public private(set) lazy var addMultichainWalletRepository = AddMultichainWalletTooltipRepository()

    public private(set) lazy var service: TooltipsService = TooltipsServiceImplementation(
        tooltipControllerFactory: tooltipControllerFactory,
        viewControllerFactory: TooltipViewControllerFactoryImplementation()
    )

    private lazy var tooltipControllerFactory: TooltipControllerFactory = TooltipControllerFactoryImplementation(
        commonTooltipsRepository: commonDataRepository,
        withdrawTooltipRepository: withdrawButtonRepository,
        newHistoryEntryPointTooltipRepository: newHistoryEntryPointRepository,
        tradeTabTooltipRepository: tradeTabRepository,
        favoriteTooltipRepository: favoriteRepository,
        addMultichainWalletTooltipRepository: addMultichainWalletRepository,
        calendar: .current
    )
}
