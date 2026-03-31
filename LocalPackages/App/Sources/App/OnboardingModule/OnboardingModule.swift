import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit

@MainActor
public struct OnboardingModule {
    private let dependencies: Dependencies
    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func createOnboardingCoordinator() -> OnboardingCoordinator {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()

        return OnboardingCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            coreAssembly: dependencies.coreAssembly,
            keeperCoreOnboardingAssembly: dependencies.keeperCoreOnboardingAssembly,
            configurationAssembly: dependencies.configurationAssembly
        )
    }
}

public extension OnboardingModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly
        let configurationAssembly: ConfigurationAssembly

        public init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly,
            configurationAssembly: ConfigurationAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreOnboardingAssembly = keeperCoreOnboardingAssembly
            self.configurationAssembly = configurationAssembly
        }
    }
}
