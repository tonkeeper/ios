import Foundation

public protocol LogBackend {
    func log(_ record: LogRecord)
}
