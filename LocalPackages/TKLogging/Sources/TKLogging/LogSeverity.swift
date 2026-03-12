import Foundation

public enum LogSeverity: Int, CaseIterable, Comparable, Sendable {
    case debug
    case info
    case warning
    case error

    public static func < (lhs: LogSeverity, rhs: LogSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
