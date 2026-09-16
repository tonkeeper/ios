import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit

@MainActor
struct OnboardingModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createOnboardingCoordinator() -> OnboardingCoordinator {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()

        return OnboardingCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            coreAssembly: dependencies.coreAssembly,
            keeperCoreOnboardingAssembly: dependencies.keeperCoreOnboardingAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            multichainAssembly: dependencies.multichainAssembly,
            configurationAssembly: dependencies.configurationAssembly
        )
    }
}

extension OnboardingModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly
        let multichainAssembly: MultichainAssembly
        let configurationAssembly: ConfigurationAssembly

        init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly,
            multichainAssembly: MultichainAssembly,
            configurationAssembly: ConfigurationAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreOnboardingAssembly = keeperCoreOnboardingAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
            self.multichainAssembly = multichainAssembly
            self.configurationAssembly = configurationAssembly
        }
    }
}
