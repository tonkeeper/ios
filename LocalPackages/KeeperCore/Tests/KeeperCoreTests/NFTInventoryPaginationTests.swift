import Foundation
@testable import KeeperCore
import XCTest

final class NFTInventoryPaginationTests: XCTestCase {
    func testBoundarySizes() async throws {
        for count in [0, 1, 999, 1000, 1001, 2501] {
            let source = Array(0..<count)
            var offsets = [Int]()
            let result = try await loadCompleteNFTInventory(identity: String.init) { limit, offset in
                offsets.append(offset)
                return Array(source.dropFirst(offset).prefix(limit))
            }
            XCTAssertEqual(result, source)
            XCTAssertEqual(offsets.last, count)
        }
    }

    func testShortServerPagesAreNotTreatedAsTheEnd() async throws {
        let source = Array(0..<1001)
        var offsets = [Int]()
        let result = try await loadCompleteNFTInventory(identity: String.init) { _, offset in
            offsets.append(offset)
            return Array(source.dropFirst(offset).prefix(37))
        }
        XCTAssertEqual(result, source)
        XCTAssertEqual(offsets.last, 1001)
    }

    func testOverlappingPagesAdvanceByRawSize() async throws {
        var offsets = [Int]()
        let result = try await loadCompleteNFTInventory(identity: String.init) { _, offset in
            offsets.append(offset)
            switch offset {
            case 0: return [1, 2]
            case 2: return [2, 3]
            default: return []
            }
        }
        XCTAssertEqual(result, [1, 2, 3])
        XCTAssertEqual(offsets, [0, 2, 4])
    }

    func testLossyMappingRunsAfterAllRawPages() async throws {
        let raw = try await loadCompleteNFTInventory(identity: { $0 }) { _, offset in
            switch offset {
            case 0: return ["invalid-a", "invalid-b"]
            case 2: return ["42"]
            default: return []
            }
        }
        XCTAssertEqual(raw.compactMap(Int.init), [42])
    }

    func testRepeatedPageFailsInsteadOfLooping() async {
        var calls = 0
        do {
            _ = try await loadCompleteNFTInventory(identity: String.init) { _, _ in
                calls += 1
                return [1, 2]
            }
            XCTFail("Repeated page must fail")
        } catch NFTInventoryPaginationError.nonProgressingPage {
            XCTAssertEqual(calls, 2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testErrorDoesNotReturnPartialResultAndRetryStartsAtZero() async throws {
        enum Failure: Error { case unavailable }
        do {
            _ = try await loadCompleteNFTInventory(identity: String.init) { _, offset in
                if offset > 0 { throw Failure.unavailable }
                return [1, 2]
            }
            XCTFail("Partial result must not be returned")
        } catch Failure.unavailable {}
        var offsets = [Int]()
        let retried = try await loadCompleteNFTInventory(identity: String.init) { _, offset in
            offsets.append(offset)
            return offset == 0 ? [3] : []
        }
        XCTAssertEqual(retried, [3])
        XCTAssertEqual(offsets, [0, 1])
    }

    func testCancellationBeforeAndDuringFetch() async {
        for cancelBefore in [true, false] {
            let task = Task {
                var calls = 0
                if cancelBefore {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
                do {
                    _ = try await loadCompleteNFTInventory(identity: String.init) { _, _ in
                        calls += 1
                        withUnsafeCurrentTask { $0?.cancel() }
                        return [1]
                    }
                    return false
                } catch is CancellationError {
                    return calls == (cancelBefore ? 0 : 1)
                } catch {
                    return false
                }
            }
            let cancelled = await task.value
            XCTAssertTrue(cancelled)
        }
    }
}
