import Foundation

public protocol LogBackend {
    var identifier: String { get }

    func log(_ record: LogRecord)
}

public extension LogBackend {
    var identifier: String {
        String(reflecting: Self.self)
    }
}
