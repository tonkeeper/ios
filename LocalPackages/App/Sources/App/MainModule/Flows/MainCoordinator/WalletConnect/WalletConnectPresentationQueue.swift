import UIKit

final class WalletConnectPresentationQueue {
    private(set) var activeKey: WalletConnectPresentationKey?
    private var pendingItems = [WalletConnectPresentationItem]()

    func enqueue(_ item: WalletConnectPresentationItem) -> WalletConnectPresentationItem? {
        guard !contains(item.key) else {
            return nil
        }
        pendingItems.append(item)
        return nextIfIdle()
    }

    func finish(_ key: WalletConnectPresentationKey) -> WalletConnectPresentationItem? {
        guard activeKey == key else {
            return nil
        }
        activeKey = nil
        return nextIfIdle()
    }

    func isActive(_ key: WalletConnectPresentationKey) -> Bool {
        activeKey == key
    }

    @discardableResult
    func removeQueued(_ key: WalletConnectPresentationKey) -> Bool {
        let count = pendingItems.count
        pendingItems.removeAll { $0.key == key }
        return pendingItems.count != count
    }

    @discardableResult
    func removeQueuedRequests(topic: String) -> Bool {
        let count = pendingItems.count
        pendingItems.removeAll {
            guard case let .request(requestKey) = $0.key else {
                return false
            }
            return requestKey.topic == topic
        }
        return pendingItems.count != count
    }
}

private extension WalletConnectPresentationQueue {
    func contains(_ key: WalletConnectPresentationKey) -> Bool {
        activeKey == key || pendingItems.contains { $0.key == key }
    }

    func nextIfIdle() -> WalletConnectPresentationItem? {
        guard activeKey == nil,
              !pendingItems.isEmpty
        else {
            return nil
        }
        let item = pendingItems.removeFirst()
        activeKey = item.key
        return item
    }
}
