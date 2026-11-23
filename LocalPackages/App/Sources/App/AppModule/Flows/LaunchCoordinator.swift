import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

public final class LaunchCoordinator: RouterCoordinator<WindowRouter> {
    private let featureFlags: TKFeatureFlags
    private weak var appCoordinator: AppCoordinator?
    private var pendingDeeplinkState = PendingDeeplinkState()
    private var loadingTask: Task<Void, Never>?

    private let coreAssembly: CoreAssembly

    /// `coreAssembly` is the one built at launch, if any: it already runs the device session.
    public init(
        router: WindowRouter,
        remoteConfig: any RemoteConfigProvider,
        coreAssembly: CoreAssembly? = nil
    ) {
        let coreAssembly = coreAssembly ?? Self.makeCoreAssembly(remoteConfig: remoteConfig)
        self.coreAssembly = coreAssembly
        self.featureFlags = coreAssembly.featureFlags
        super.init(router: router)
    }

    /// Reads no flag: they are read only after `loadRemoteConfig()`.
    public static func makeCoreAssembly(remoteConfig: any RemoteConfigProvider) -> CoreAssembly {
        CoreAssembly(
            featureFlags: TKFeatureFlagsImplementation(
                remoteConfigProvider: remoteConfig,
                overrides: StaticFlagOverrides.shared?.featureFlags ?? [:]
            )
        )
    }

    override public func start(deeplink: CoordinatorDeeplink? = nil) {
        pendingDeeplinkState.append(deeplink, isColdStart: true)
        openLaunchScreen()

        guard loadingTask == nil else { return }
        // The first frame's fonts and strings load while the main thread waits for the remote config.
        DispatchQueue.global(qos: .userInitiated).async {
            TKTextStyle.warmUp()
            _ = TKLocales.Tabs.trade
        }
        loadingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            await featureFlags.loadRemoteConfig()
            guard !Task.isCancelled else { return }
            ScreenRenderTracker.shared.launchMark(.remoteConfigLoaded)

            let appCoordinator = AppCoordinator(
                router: router,
                coreAssembly: coreAssembly
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
