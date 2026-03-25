import Foundation

public enum Log {
    private static let lock = NSLock()
    private static var _configuration: LoggingConfiguration = .default

    public static var configuration: LoggingConfiguration {
        get {
            lock.withLock {
                _configuration
            }
        }
        set {
            lock.withLock {
                _configuration = newValue
            }
        }
    }

    public static var `default`: LogDomain {
        LogDomain(category: "default")
    }

    public static func d(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        extraInfo: [String: String] = [:]
    ) {
        self.default.d(message(), file: file, function: function, line: line, extraInfo: extraInfo)
    }

    public static func i(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        extraInfo: [String: String] = [:]
    ) {
        self.default.i(message(), file: file, function: function, line: line, extraInfo: extraInfo)
    }

    public static func w(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        extraInfo: [String: String] = [:]
    ) {
        self.default.w(message(), file: file, function: function, line: line, extraInfo: extraInfo)
    }

    public static func e(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        extraInfo: [String: String] = [:]
    ) {
        self.default.e(message(), file: file, function: function, line: line, extraInfo: extraInfo)
    }
}

public extension LogDomain {
    static var inAppPurchases: LogDomain {
        LogDomain(category: "InAppPurchases")
    }

    static var nativeSwapAPI: LogDomain {
        LogDomain(category: "NativeSwapAPI")
    }

    static var signRaw: LogDomain {
        LogDomain(category: "SignRaw")
    }

    static var consoleAnalytics: LogDomain {
        LogDomain(category: "ConsoleAnalyticsLogger")
    }
}

public extension Log {
    static var inAppPurchases: LogDomain {
        .inAppPurchases
    }

    static var signRaw: LogDomain {
        .signRaw
    }

    static var nativeSwapAPI: LogDomain {
        .nativeSwapAPI
    }

    static var consoleAnalytics: LogDomain {
        .consoleAnalytics
    }
}
