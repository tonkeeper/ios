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
            keeperCoreOnboardingAssembly: dependencies.keeperCoreOnboardingAssembly
        )
    }
}

public extension OnboardingModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly

        public init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreOnboardingAssembly = keeperCoreOnboardingAssembly
        }
    }
}
