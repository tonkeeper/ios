import Foundation

/// Mirror of the SDK's internal `EnvironmentInfo`, which is not visible outside the `Aptabase` module.
/// Values must stay identical to the SDK's so both transports land in the same server buckets.
struct AptabaseEnvironment {
    /// Kept identical to the pinned SDK's `AptabaseClient.sdkVersion`: dashboards filter on it,
    /// and the cohort split rides on the `analytics_transport` property instead.
    static let sdkVersion = "aptabase-swift@0.3.11"

    var isDebug: Bool
    let osName: String
    let osVersion: String
    let locale: String
    let appVersion: String
    let appBuildNumber: String
    let deviceModel: String

    /// Built wherever `CoreAssembly.analyticsProvider` is first touched, which carries no main-thread
    /// guarantee, so nothing here reads `@MainActor`-isolated `UIDevice`. The SDK's two `UIDevice` values
    /// are still reproduced exactly: `operatingSystemVersion` is what `systemVersion` formats, and the app
    /// target is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), so the SDK's idiom check can only yield `iOS`
    /// — revisit `osName` if the app ever ships for iPad.
    static func current() -> AptabaseEnvironment {
        AptabaseEnvironment(
            isDebug: isDebugBuild,
            osName: "iOS",
            osVersion: osVersion,
            locale: Locale.current.languageCode ?? "",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            appBuildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            deviceModel: deviceModel
        )
    }

    var systemProps: AptabaseEvent.SystemProps {
        AptabaseEvent.SystemProps(
            isDebug: isDebug,
            locale: locale,
            osName: osName,
            osVersion: osVersion,
            appVersion: appVersion,
            appBuildNumber: appBuildNumber,
            sdkVersion: Self.sdkVersion,
            deviceModel: deviceModel
        )
    }

    var userAgent: String {
        "\(osName)/\(osVersion) \(locale)"
    }

    private static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let shortVersion = "\(version.majorVersion).\(version.minorVersion)"
        return version.patchVersion > 0 ? shortVersion + ".\(version.patchVersion)" : shortVersion
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
            true
        #else
            false
        #endif
    }

    private static var deviceModel: String {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        }
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return "" }
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { machinePointer in
                String(cString: machinePointer)
            }
        }
    }
}
