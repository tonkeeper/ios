import Foundation
import UIKit

@MainActor
final class PerpsWaitMeasurement {
    private var startedAt: TimeInterval?
    private var isDirty = false
    private var backgroundObserver: NSObjectProtocol?

    init() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isDirty = true
            }
        }
    }

    deinit {
        backgroundObserver.map(NotificationCenter.default.removeObserver)
    }

    func begin() {
        startedAt = ProcessInfo.processInfo.systemUptime
    }

    func dirtying(_ passcodeProvider: @escaping @Sendable () async -> String?) -> @Sendable () async -> String? {
        { [weak self] in
            await self?.markDirty()
            return await passcodeProvider()
        }
    }

    func cleanMilliseconds() -> Int64? {
        guard let startedAt, !isDirty else { return nil }
        return Int64(((ProcessInfo.processInfo.systemUptime - startedAt) * 1000).rounded())
    }

    private func markDirty() {
        isDirty = true
    }
}
