import Foundation

public struct ScreenRenderID: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let portfolio = ScreenRenderID("portfolio")
    public static let history = ScreenRenderID("history")
    public static let trade = ScreenRenderID("trade")
    public static let browser = ScreenRenderID("browser")
}

public enum ScreenRenderTrigger: String, Sendable {
    case inApp = "in_app"
    case appLaunch = "app_launch"
    case deeplink
    case push
    case auto
}

public enum ScreenRenderOutcome: String, Sendable {
    case fresh
    case cachedOnly = "cached_only"
    case failed
    case abandoned
    case timeout
}

public enum ScreenRenderErrorKind: String, Sendable {
    case timeout
    case offline
    case network
    case server
    case decode
    case unknown
}

public enum ScreenRenderStage: Sendable {
    case cached
    case fresh
}

public enum ScreenRenderLifecycle: Sendable {
    case viewDidLoad
    case viewWillAppear
    case viewDidAppear
}

/// Steps of a cold launch, reported among the launch session's marks.
public enum ScreenRenderLaunchStep: String, Sendable {
    case didFinishLaunching = "did_finish_launching"
    case sceneConnect = "scene_connect"
    case remoteConfigLoaded = "remote_config_loaded"
    case rootStart = "root_start"
    case passcodeShown = "passcode_shown"
    case passcodeEntered = "passcode_entered"
    case mainStart = "main_start"
}

/// A screen-specific step; each screen declares its own names as static constants.
public struct ScreenRenderMarkName: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct ScreenRenderMark: Equatable, Sendable {
    public let name: String
    public let ms: Int64
}

public struct ScreenRenderReport: Equatable, Sendable {
    public let screen: ScreenRenderID
    public let trigger: ScreenRenderTrigger
    public let outcome: ScreenRenderOutcome
    public let isFirstOpen: Bool
    public let cachedMs: Int64?
    public let freshMs: Int64?
    public let viewDidLoadMs: Int64?
    public let willAppearMs: Int64?
    public let didAppearMs: Int64?
    public let requestMs: Int64?
    public let errorKind: ScreenRenderErrorKind?
    /// Time the launch waited for the user; left out of every other time.
    public let pausedMs: Int64?
    /// Set on cold-launch sessions only.
    public let hadPasscode: Bool?
    public let marks: [ScreenRenderMark]
}

@MainActor
public protocol ScreenRenderReporter: AnyObject {
    func report(_ report: ScreenRenderReport)
}
