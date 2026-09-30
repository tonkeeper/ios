import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushAuthorizationModel {
    private(set) var isGranted = false

    private var observers = [UUID: () -> Void]()
    private var generation = 0
    private var didBecomeActiveObserver: NSObjectProtocol?

    init() {
        // The permission prompt does not trigger a foreground transition.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        refresh()
    }

    deinit {
        didBecomeActiveObserver.map(NotificationCenter.default.removeObserver)
    }

    func addObserver<T: AnyObject>(_ observer: T, closure: @escaping (T) -> Void) {
        let id = UUID()
        observers[id] = { [weak self, weak observer] in
            guard let observer else {
                self?.observers.removeValue(forKey: id)
                return
            }
            closure(observer)
        }
    }

    private func refresh() {
        generation += 1
        let generation = generation
        Task { @MainActor [weak self] in
            let isGranted = await UNUserNotificationCenter.current()
                .notificationSettings()
                .authorizationStatus.isPushAuthorized
            self?.apply(isGranted, generation: generation)
        }
    }

    private func apply(_ isGranted: Bool, generation: Int) {
        guard generation == self.generation, self.isGranted != isGranted else { return }
        self.isGranted = isGranted
        // Observers may mutate the table while handling this update.
        let observers = observers
        for observer in observers.values {
            observer()
        }
    }
}
