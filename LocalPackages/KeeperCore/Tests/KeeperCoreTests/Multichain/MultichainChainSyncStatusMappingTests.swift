@testable import KeeperCore
import MultichainAPI
import XCTest

final class MultichainChainSyncStatusMappingTests: XCTestCase {
    func test_unknownValuesMapToTerminalStatesSoPollingStops() {
        XCTAssertEqual(MultichainChainSyncStatus.Status(api: .unknown), .failed)
        XCTAssertEqual(MultichainChainSyncStatus.Backfill(api: .unknown), .complete)
    }
}
