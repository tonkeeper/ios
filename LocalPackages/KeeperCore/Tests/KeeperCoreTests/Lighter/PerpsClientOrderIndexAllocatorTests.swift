import ChainKit
import Foundation
@testable import KeeperCore
import XCTest

final class PerpsClientOrderIndexAllocatorTests: XCTestCase {
    func testAllocatorPersistsAcrossInstances() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try await PerpsClientOrderIndexAllocator(directoryURL: directory)
            .reserve(nowUnixMs: LighterConstants.shared.MinClientOrderIndex)
        let second = try await PerpsClientOrderIndexAllocator(directoryURL: directory)
            .reserve(nowUnixMs: LighterConstants.shared.MinClientOrderIndex)

        XCTAssertGreaterThan(second.order, first.stopLoss)
    }

    func testConcurrentReservationsNeverShareAnIndex() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let allocator = PerpsClientOrderIndexAllocator(directoryURL: directory)
        let now = LighterConstants.shared.MinClientOrderIndex

        let reserved = try await withThrowingTaskGroup(of: PerpsClientOrderIndices.self) { group in
            for _ in 0 ..< 10 {
                group.addTask { try await allocator.reserve(nowUnixMs: now) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        let indices = reserved.flatMap { [$0.order, $0.takeProfit, $0.stopLoss] }
        XCTAssertEqual(Set(indices).count, indices.count)
    }

    func testAnUnreadableFileDoesNotStopOrdersFromBeingNumbered() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("client-order-index.json"))

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let indices = try await PerpsClientOrderIndexAllocator(directoryURL: directory).reserve(nowUnixMs: now)

        XCTAssertEqual(indices.order, now)
    }

    func testAPersistedIndexOutsideTheProtocolRangeIsIgnored() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"last":281474976710655}"#.utf8)
            .write(to: directory.appendingPathComponent("client-order-index.json"))

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let indices = try await PerpsClientOrderIndexAllocator(directoryURL: directory).reserve(nowUnixMs: now)

        XCTAssertEqual(indices.order, now)
    }

    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsClientOrderIndexAllocatorTests-\(UUID().uuidString)", isDirectory: true)
    }
}
