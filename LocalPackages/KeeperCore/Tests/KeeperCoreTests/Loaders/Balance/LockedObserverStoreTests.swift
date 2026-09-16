@testable import KeeperCore
import XCTest

final class LockedObserverStoreTests: XCTestCase {
    func test_notifyInvokesLiveObserver() {
        let store = LockedObserverStore<Int>()
        let observer = TestObserver()

        store.add(observer) { observer, value in
            observer.values.append(value)
        }
        store.notify(42)

        XCTAssertEqual(observer.values, [42])
    }

    func test_notifyRemovesDeallocatedObserver() throws {
        let store = LockedObserverStore<Void>()
        var observer: TestObserver? = TestObserver()
        try store.add(XCTUnwrap(observer)) { _, _ in
            XCTFail("Deallocated observer must not be called")
        }

        observer = nil
        store.notify(())

        XCTAssertEqual(store.count, 0)
    }

    func test_addDuringNotificationUsesSnapshot() {
        let store = LockedObserverStore<Void>()
        let firstObserver = TestObserver()
        let secondObserver = TestObserver()

        store.add(firstObserver) { observer, _ in
            observer.callCount += 1
            if observer.callCount == 1 {
                store.add(secondObserver) { observer, _ in
                    observer.callCount += 1
                }
            }
        }

        store.notify(())
        XCTAssertEqual(firstObserver.callCount, 1)
        XCTAssertEqual(secondObserver.callCount, 0)

        store.notify(())
        XCTAssertEqual(firstObserver.callCount, 2)
        XCTAssertEqual(secondObserver.callCount, 1)
    }

    func test_concurrentNotificationsInvokeObserverExactlyOncePerNotification() {
        let store = LockedObserverStore<Void>()
        let observer = TestObserver()
        let iterations = 1000

        store.add(observer) { observer, _ in
            observer.incrementCallCount()
        }

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            store.notify(())
        }

        XCTAssertEqual(observer.threadSafeCallCount, iterations)
    }

    func test_notifyUsesCallingQueue() {
        let store = LockedObserverStore<Void>()
        let observer = TestObserver()
        let queue = DispatchQueue(label: "LockedObserverStoreTests.callingQueue")
        let queueKey = DispatchSpecificKey<Void>()
        queue.setSpecific(key: queueKey, value: ())

        store.add(observer) { _, _ in
            XCTAssertNotNil(DispatchQueue.getSpecific(key: queueKey))
        }

        queue.sync {
            store.notify(())
        }
    }
}

private final class TestObserver {
    private let lock = NSLock()
    var values = [Int]()
    var callCount = 0

    var threadSafeCallCount: Int {
        lock.withLock {
            callCount
        }
    }

    func incrementCallCount() {
        lock.withLock {
            callCount += 1
        }
    }
}
