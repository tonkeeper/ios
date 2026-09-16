import Foundation
@testable import KeeperCore
import TKLogging
import XCTest

final class WalletConnectErrorMapperTests: XCTestCase {
    func testWalletConnectLogDescriptionIncludesFailureStageWithoutReason() {
        let reason = "signature verification failed"
        let error = WalletConnectSigningError.failedToSign(reason: reason)

        XCTAssertEqual(
            error.logDescription,
            "type=WalletConnectSigningError, case=failedToSign"
        )
        XCTAssertFalse(error.logDescription.contains(reason))
    }

    func testWalletConnectLogDescriptionExcludesSessionIdentifiers() {
        let topic = "sensitive-session-topic"
        let walletId = "sensitive-wallet-id"
        let error = WalletConnectSigningError.missingMultichainAddress(
            chain: .eth,
            walletId: walletId
        )

        XCTAssertFalse(error.logDescription.contains(topic))
        XCTAssertFalse(error.logDescription.contains(walletId))
        XCTAssertFalse(WalletConnectResponseError.missingSession(topic: topic).logDescription.contains(topic))
    }

    func testPairingRetryableNetworkErrorMapsToNetworkError() {
        let error = WalletConnectPairingErrorMapper.map(URLError(.notConnectedToInternet))

        guard case .network = error else {
            XCTFail("Expected network error, got \(error)")
            return
        }
        XCTAssertTrue(error.isRetryableDeliveryFailure)
        XCTAssertEqual(error.errorDescription, "Check your connection and try again.")
    }

    func testResponseRetryableNetworkNSErrorMapsToRetryableSDKError() {
        let sourceError = NSError(
            domain: NSURLErrorDomain,
            code: URLError.Code.timedOut.rawValue
        )

        let error = WalletConnectResponseErrorMapper.map(
            sourceError,
            requestId: "request",
            topic: "topic"
        )

        guard case let .sdk(_, retryable) = error else {
            XCTFail("Expected sdk error, got \(error)")
            return
        }
        XCTAssertTrue(retryable)
    }

    func testResponseRelayRequestTimeoutMapsToRetryableSDKError() {
        let error = WalletConnectResponseErrorMapper.map(
            RelayRequestTimeoutError(),
            requestId: "request",
            topic: "topic"
        )

        guard case let .sdk(message, retryable) = error else {
            XCTFail("Expected sdk error, got \(error)")
            return
        }
        XCTAssertEqual(message, "Relay request timeout")
        XCTAssertTrue(retryable)
    }

    func testPairingWrappedNetworkNSErrorMapsToNetworkError() {
        let sourceError = NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(POSIXErrorCode.ECONNRESET.rawValue)
        )
        let wrappedError = NSError(
            domain: "com.reown.test",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: sourceError]
        )

        let error = WalletConnectPairingErrorMapper.map(wrappedError)

        guard case .network = error else {
            XCTFail("Expected network error, got \(error)")
            return
        }
        XCTAssertTrue(error.isRetryableDeliveryFailure)
    }
}

private struct RelayRequestTimeoutError: LocalizedError {
    var errorDescription: String? {
        "Relay request timeout"
    }
}
