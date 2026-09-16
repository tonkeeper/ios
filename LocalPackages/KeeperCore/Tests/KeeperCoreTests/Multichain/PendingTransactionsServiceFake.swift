import Foundation
@testable import KeeperCore

actor PendingTransactionsServiceFake: PendingTransactionsService {
    private(set) var reported = [MultichainPendingTransaction]()
    private(set) var flushCount = 0

    func report(_ transaction: MultichainPendingTransaction) async {
        reported.append(transaction)
    }

    func flushRetained() async {
        flushCount += 1
    }
}
