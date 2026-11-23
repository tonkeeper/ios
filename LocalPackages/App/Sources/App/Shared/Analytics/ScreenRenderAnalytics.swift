import Foundation
import KeeperCore
import TKCore
import TKUIKit

@MainActor
final class ScreenRenderAnalytics: ScreenRenderReporter {
    private let analyticsProvider: AnalyticsProvider
    private let reachabilityTracker: ReachabilityTracker
    private let walletsStore: WalletsStore

    init(analyticsProvider: AnalyticsProvider, reachabilityTracker: ReachabilityTracker, walletsStore: WalletsStore) {
        self.analyticsProvider = analyticsProvider
        self.reachabilityTracker = reachabilityTracker
        self.walletsStore = walletsStore
    }

    func report(_ report: ScreenRenderReport) {
        guard let screen = AppScreen(rawValue: report.screen.rawValue),
              let wallet = try? walletsStore.activeWallet
        else { return }
        let processInfo = ProcessInfo.processInfo
        let interfaceType = reachabilityTracker.interfaceType
        analyticsProvider.log(
            ScreenContentRendered(
                screen: screen,
                walletMode: WalletMode(wallet: wallet),
                trigger: ScreenContentRendered.Trigger(report.trigger),
                outcome: ScreenContentRendered.Outcome(report.outcome),
                errorKind: report.errorKind.map { ScreenContentRendered.ErrorKind($0, interfaceType: interfaceType) },
                isFirstOpen: report.isFirstOpen,
                cachedMs: report.cachedMs,
                freshMs: report.freshMs,
                screenCreatedMs: report.viewDidLoadMs,
                screenWillShowMs: report.willAppearMs,
                screenShownMs: report.didAppearMs,
                requestMs: report.requestMs,
                marks: report.marks.isEmpty ? nil : report.marks.map { "\($0.name):\($0.ms)" }.joined(separator: ";"),
                pausedMs: report.pausedMs,
                hadPasscode: report.hadPasscode,
                networkType: ScreenContentRendered.NetworkType(interfaceType),
                isLowPower: processInfo.isLowPowerModeEnabled,
                thermalState: ScreenContentRendered.ThermalState(processInfo.thermalState)
            )
        )
    }
}

private extension ScreenContentRendered.Trigger {
    init(_ trigger: ScreenRenderTrigger) {
        switch trigger {
        case .inApp: self = .inApp
        case .appLaunch: self = .appLaunch
        case .deeplink: self = .deeplink
        case .push: self = .push
        case .auto: self = .auto
        }
    }
}

private extension ScreenContentRendered.Outcome {
    init(_ outcome: ScreenRenderOutcome) {
        switch outcome {
        case .fresh: self = .fresh
        case .cachedOnly: self = .cachedOnly
        case .failed: self = .failed
        case .abandoned: self = .abandoned
        case .timeout: self = .timeout
        }
    }
}

private extension ScreenContentRendered.ErrorKind {
    /// Services report a lost connection as a generic network failure; the path monitor tells it apart.
    init(_ errorKind: ScreenRenderErrorKind, interfaceType: ReachabilityTracker.InterfaceType) {
        switch errorKind {
        case .timeout: self = .timeout
        case .offline: self = .offline
        case .network: self = interfaceType == .none ? .offline : .network
        case .server: self = .server
        case .decode: self = .decode
        case .unknown: self = .unknown
        }
    }
}

private extension ScreenContentRendered.NetworkType {
    init(_ interfaceType: ReachabilityTracker.InterfaceType) {
        switch interfaceType {
        case .wifi: self = .wifi
        case .cellular: self = .cellular
        case .wired: self = .wired
        case .other: self = .other
        case .none: self = ._none
        }
    }
}

private extension ScreenContentRendered.ThermalState {
    init(_ thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
}
