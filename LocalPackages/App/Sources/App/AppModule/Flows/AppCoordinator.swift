import KeeperCore
import SnapKit
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKUIKit
import UIKit
import UserNotifications
import WidgetKit

final class AppCoordinator: RouterCoordinator<WindowRouter> {
    private static let bootConfigurationDeadline: UInt64 = 3000

    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreAssembly: KeeperCore.Assembly

    private let appStateTracker: AppStateTracker

    private weak var rootCoordinator: RootCoordinator?

    init(
        router: WindowRouter,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreAssembly = coreAssembly.keeperCoreAssembly
        self.appStateTracker = coreAssembly.appStateTracker
        super.init(router: router)
    }

    override func start(deeplink: CoordinatorDeeplink? = nil) {
        makeTKUIKitInitialSetup()
        setupSensitiveContentAnalytics()

        var settingsRepository = keeperCoreAssembly.repositoriesAssembly.settingsRepository()
        if settingsRepository.isFirstRun {
            settingsRepository.isFirstRun = false
            settingsRepository.seed = UUID().uuidString
        }

        logLaunchApp()

        openRoot(deeplink: deeplink)

        appStateTracker.addObserver(self)
    }

    override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
        guard let rootCoordinator else { return false }
        return rootCoordinator.handleDeeplink(deeplink: deeplink)
    }

    private func makeTKUIKitInitialSetup() {
        ToastPresenter.windowLevel = .toast
    }

    /// Flag values are only final once the boot config is loaded, so the event waits for it,
    /// but never longer than `bootConfigurationDeadline` — a stalled network must not drop the event.
    /// The permission read runs alongside that wait and is not covered by the same bound.
    private func logLaunchApp() {
        let theme = TKThemeManager.shared.theme.analyticsTheme
        let walletsCount = keeperCoreAssembly.rootAssembly().storesAssembly.walletsStore.wallets.count
        let configuration = keeperCoreAssembly.configurationAssembly.configuration
        Task { [analyticsProvider = coreAssembly.analyticsProvider, configuration] in
            async let pushPermission = UNUserNotificationCenter.current()
                .notificationSettings()
                .authorizationStatus
                .analyticsPushPermission
            let deadline = Task {
                try? await Task.sleep(nanoseconds: Self.bootConfigurationDeadline * NSEC_PER_MSEC)
            }
            Task {
                _ = await configuration.loadConfigurations()
                deadline.cancel()
            }
            await deadline.value

            let event = LaunchApp(
                theme: theme,
                walletsCount: walletsCount,
                pushPermission: await pushPermission
            )
            analyticsProvider.log(
                event.withExtraValues(configuration.resolvedFeatureFlags.analyticsParameters)
            )
        }
    }

    private func setupSensitiveContentAnalytics() {
        TKSensitiveContentController.didTakeScreenshot = { [analyticsProvider = coreAssembly.analyticsProvider] in
            analyticsProvider.log(eventKey: .sensitiveContentScreenshot)
        }
    }
}

private extension AppCoordinator {
    func openRoot(deeplink: TKCoordinator.CoordinatorDeeplink? = nil) {
        let rootCoordinator = RootCoordinator(
            router: ViewControllerRouter(rootViewController: AppCoordinatorRootViewController()),
            dependencies: RootCoordinator.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreRootAssembly: keeperCoreAssembly.rootAssembly()
            )
        )
        self.router.window.rootViewController = rootCoordinator.router.rootViewController

        self.rootCoordinator = rootCoordinator

        addChild(rootCoordinator)
        rootCoordinator.start(deeplink: deeplink)
    }
}

extension AppCoordinator: AppStateTrackerObserver {
    func didUpdateState(_ state: AppStateTracker.State) {
        switch state {
        case .resign:
            WidgetCenter.shared.reloadAllTimelines()
        default:
            break
        }
    }
}

class AppCoordinatorRootViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let launchScreen = LaunchScreenViewController()
        addChild(launchScreen)
        view.addSubview(launchScreen.view)
        launchScreen.didMove(toParent: self)

        launchScreen.view.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
    }
}

private extension UNAuthorizationStatus {
    var analyticsPushPermission: LaunchApp.PushPermission? {
        switch self {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        case .notDetermined: .notRequested
        @unknown default: nil
        }
    }
}

private extension TKTheme {
    var analyticsTheme: LaunchApp.Theme {
        switch self {
        case .deepBlue: return .deepBlue
        case .dark: return .dark
        case .light: return .light
        case .system:
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark
                ? .systemDark
                : .systemLight
        }
    }
}
