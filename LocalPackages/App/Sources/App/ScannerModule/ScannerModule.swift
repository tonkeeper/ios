import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit

struct ScannerModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createScannerModule(
        configurator: ScannerControllerConfigurator,
        uiConfiguration: ScannerUIConfiguration,
        analytics: ScannerAnalytics
    ) -> MVVMModule<ScannerViewController, ScannerViewModuleOutput, Void> {
        let analyticsSession: ScanAnalyticsSession? = switch analytics {
        case let .scanEvents(openUtm):
            ScanAnalyticsSession(analyticsProvider: dependencies.coreAssembly.analyticsProvider, openUtm: openUtm)
        case .none:
            nil
        }
        return ScannerAssembly.module(
            scannerController: dependencies.scannerAssembly.scannerController(configurator: configurator),
            urlOpener: dependencies.coreAssembly.urlOpener(),
            uiConfiguration: uiConfiguration,
            analyticsSession: analyticsSession
        )
    }
}

extension ScannerModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let scannerAssembly: KeeperCore.ScannerAssembly

        init(
            coreAssembly: TKCore.CoreAssembly,
            scannerAssembly: KeeperCore.ScannerAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.scannerAssembly = scannerAssembly
        }
    }
}
