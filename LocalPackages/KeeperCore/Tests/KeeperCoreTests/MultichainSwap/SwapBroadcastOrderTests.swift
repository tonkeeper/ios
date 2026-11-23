@testable import KeeperCore
import XCTest

final class SwapBroadcastOrderTests: XCTestCase {
    func testEachTransactionAfterTheFirstWaitsForTheNonceBeforeItGoesOut() async throws {
        var events: [String] = []

        let hash = try await SwapPipelineStageProviderImplementation.broadcastInOrder(
            ["a", "b", "c"],
            payloadId: "swap",
            waitForNonce: { (offset: Int) async throws(MultichainSwapExecutionFailure) in
                events.append("wait \(offset)")
            },
            broadcast: { (output: String) async throws(MultichainSwapExecutionFailure) -> String in
                events.append("send \(output)")
                return "hash \(output)"
            }
        )

        XCTAssertEqual(hash, "hash c")
        XCTAssertEqual(events, ["send a", "wait 1", "send b", "wait 2", "send c"])
    }

    func testANonceThatNeverComesStopsTheTransactionsAfterTheFirst() async {
        var sent: [String] = []

        do {
            _ = try await SwapPipelineStageProviderImplementation.broadcastInOrder(
                ["a", "b"],
                payloadId: "swap",
                waitForNonce: { (_: Int) async throws(MultichainSwapExecutionFailure) in
                    throw .canceled
                },
                broadcast: { (output: String) async throws(MultichainSwapExecutionFailure) -> String in
                    sent.append(output)
                    return output
                }
            )
            XCTFail("Expected the missing nonce to stop the swap")
        } catch {
            XCTAssertEqual(error, .canceled)
        }
        XCTAssertEqual(sent, ["a"])
    }

    func testNothingToSendFails() async {
        do {
            _ = try await SwapPipelineStageProviderImplementation.broadcastInOrder(
                [String](),
                payloadId: "swap",
                waitForNonce: { (_: Int) async throws(MultichainSwapExecutionFailure) in },
                broadcast: { (output: String) async throws(MultichainSwapExecutionFailure) -> String in output }
            )
            XCTFail("Expected a failure without outputs")
        } catch {
            guard case .signingFailed = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
    }
}
