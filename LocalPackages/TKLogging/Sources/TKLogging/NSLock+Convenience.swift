import Foundation

extension NSLock {
    func withLock<T>(_ closure: () -> T) -> T {
        lock()
        defer { unlock() }
        return closure()
    }
}
