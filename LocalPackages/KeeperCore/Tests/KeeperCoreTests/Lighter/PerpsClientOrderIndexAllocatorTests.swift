import ChainKit
import Foundation
@testable import KeeperCore
import XCTest

final class PerpsClientOrderIndexAllocatorTests: XCTestCase {
    func testAllocatorPersistsAcrossInstances() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsClientOrderIndexAllocatorTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try PerpsClientOrderIndexAllocator(directoryURL: directory)
            .next(nowUnixMs: LighterConstants.shared.MinClientOrderIndex)
        let second = try PerpsClientOrderIndexAllocator(directoryURL: directory)
            .next(nowUnixMs: LighterConstants.shared.MinClientOrderIndex)

        XCTAssertGreaterThan(second, first)
    }
}
