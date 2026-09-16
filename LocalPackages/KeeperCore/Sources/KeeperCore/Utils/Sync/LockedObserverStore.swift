import Foundation

final class LockedObserverStore<Event> {
    private typealias Observer = (Event) -> Bool

    private let lock = NSLock()
    private var observers = [UUID: Observer]()

    var count: Int {
        lock.withLock {
            observers.count
        }
    }

    func add<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, Event) -> Void
    ) {
        let id = UUID()
        let observerClosure: Observer = { [weak observer] event in
            guard let observer else { return false }
            closure(observer, event)
            return true
        }
        lock.withLock {
            observers[id] = observerClosure
        }
    }

    func notify(_ event: Event) {
        let snapshot = lock.withLock {
            observers
        }
        let expiredIDs = snapshot.compactMap { id, observer in
            observer(event) ? nil : id
        }
        guard !expiredIDs.isEmpty else { return }
        lock.withLock {
            for expiredID in expiredIDs {
                observers.removeValue(forKey: expiredID)
            }
        }
    }
}
