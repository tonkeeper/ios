import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLogging
import TKUIKit
import UIKit

public final class LaunchCoordinator: RouterCoordinator<WindowRouter> {
    private let featureFlags: TKFeatureFlags
    private weak var appCoordinator: AppCoordinator?
    private var pendingDeeplinkState = PendingDeeplinkState()
    private var loadingTask: Task<Void, Never>?

    public init(
        router: WindowRouter,
        remoteConfig: any RemoteConfigProvider
    ) {
        self.featureFlags = TKFeatureFlagsImplementation(
            remoteConfigProvider: remoteConfig,
            overrides: StaticFlagOverrides.shared?.featureFlags ?? [:]
        )
        super.init(router: router)
    }

    override public func start(deeplink: CoordinatorDeeplink? = nil) {
        pendingDeeplinkState.append(deeplink, isColdStart: true)
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
            let pending = pendingDeeplinkState.drain()
            appCoordinator.start(
                deeplink: pending.deeplink,
                deeplinkOpenContexts: pending.analyticsContexts
            )
        }
    }

    override public func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
        if let appCoordinator {
            return appCoordinator.handleDeeplink(deeplink: deeplink)
        }

        guard let deeplink else { return false }
        pendingDeeplinkState.append(deeplink, isColdStart: false)
        return true
    }
}

private extension LaunchCoordinator {
    func openLaunchScreen() {
        router.window.rootViewController = LaunchScreenViewController()
    }
}
