import Foundation
@testable import KeeperCore
import XCTest

final class WalletConnectWebSocketTests: XCTestCase {
    func testWriteAfterDisconnectCallsCompletionAndDisconnectOnce() throws {
        let socket = try WalletConnectURLSessionWebSocket(
            url: XCTUnwrap(URL(string: "wss://relay.walletconnect.com"))
        )
        socket.disconnect()

        let completionExpectation = expectation(description: "write completion")
        completionExpectation.assertForOverFulfill = true
        let disconnectExpectation = expectation(description: "disconnect callback")
        disconnectExpectation.assertForOverFulfill = true

        var completionCalls = 0
        var disconnectCalls = 0
        var disconnectError: Error?

        socket.onDisconnect = { error in
            disconnectCalls += 1
            disconnectError = error
            disconnectExpectation.fulfill()
        }

        socket.write(string: "{}", completion: {
            completionCalls += 1
            completionExpectation.fulfill()
        })

        wait(for: [completionExpectation, disconnectExpectation], timeout: 1)
        XCTAssertEqual(completionCalls, 1)
        XCTAssertEqual(disconnectCalls, 1)
        XCTAssertNotNil(disconnectError)
        XCTAssertFalse(socket.isConnected)
    }
}
