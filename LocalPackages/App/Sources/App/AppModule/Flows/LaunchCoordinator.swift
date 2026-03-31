import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLogging
import UIKit

public final class LaunchCoordinator: RouterCoordinator<WindowRouter> {
    private let featureFlags: TKFeatureFlags
    private weak var appCoordinator: AppCoordinator?
    private var pendingDeeplink: CoordinatorDeeplink?
    private var loadingTask: Task<Void, Never>?

    public init(
        router: WindowRouter,
        remoteConfig: any RemoteConfigProvider
    ) {
        self.featureFlags = TKFeatureFlagsImplementation(
            remoteConfigProvider: remoteConfig
        )
        super.init(router: router)
    }

    override public func start(deeplink: CoordinatorDeeplink? = nil) {
        pendingDeeplink = deeplink
        openLaunchScreen()

        guard loadingTask == nil else { return }
        loadingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            await featureFlags.loadRemoteConfig()
            guard !Task.isCancelled else { return }

            let appCoordinator = AppCoordinator(
                router: router,
                coreAssembly: CoreAssembly(featureFlags: featureFlags)
            )
            self.appCoordinator = appCoordinator
            addChild(appCoordinator)
            appCoordinator.start(deeplink: pendingDeeplink)
            pendingDeeplink = nil
        }
    }

    override public func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
        if let appCoordinator {
            return appCoordinator.handleDeeplink(deeplink: deeplink)
        }

        guard let deeplink else { return false }
        pendingDeeplink = deeplink
        return true
    }
}

private extension LaunchCoordinator {
    func openLaunchScreen() {
        router.window.rootViewController = LaunchScreenViewController()
    }
}
