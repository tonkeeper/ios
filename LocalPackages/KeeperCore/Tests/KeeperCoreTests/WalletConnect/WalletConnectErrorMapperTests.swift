import Foundation
@testable import KeeperCore
import TKLocalize
import TKLogging
@testable import WalletConnectSign
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

    func testAReviewFailureTellsTheUserOnlyThatTheTransactionCouldNotBeVerified() {
        let error = WalletConnectSigningError.unreviewable(reason: #"malformed("the check failed")"#)

        XCTAssertEqual(error.errorDescription, TKLocales.OperationValidation.Finding.unknown)
        XCTAssertEqual(error.walletConnectRequestRejectionReason, .userRejected)
        XCTAssertEqual(error.logDescription, "type=WalletConnectSigningError, case=unreviewable")
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

    func testExpiredSDKRequestMapsToLocalizedExpiry() {
        let sdkError = SessionResponder.Errors.sessionRequestExpired
        XCTAssertEqual((sdkError as NSError).domain, "WalletConnectSign.SessionResponder.Errors")
        XCTAssertEqual((sdkError as NSError).code, 0)
        let error = WalletConnectResponseErrorMapper.map(
            sdkError,
            requestId: "request",
            topic: "topic"
        )

        XCTAssertEqual(error, .requestExpired(id: "request"))
        XCTAssertEqual(error.errorDescription, TKLocales.WalletConnect.Error.requestExpired)
        XCTAssertFalse(error.isRetryableDeliveryFailure)
    }

    func testUnrelatedSDKFailuresAreNotReportedAsExpiry() {
        let cases: [(domain: String, code: Int, requestId: String?)] = [
            ("WalletConnectSign.SessionResponder.Errors", 1, "request"),
            ("another.sdk", 0, "request"),
            ("WalletConnectSign.SessionResponder.Errors", 0, nil),
        ]
        for testCase in cases {
            let error = WalletConnectResponseErrorMapper.map(
                NSError(
                    domain: testCase.domain,
                    code: testCase.code,
                    userInfo: [NSLocalizedDescriptionKey: "Request expired"]
                ),
                requestId: testCase.requestId,
                topic: "topic"
            )

            XCTAssertEqual(error, .sdk(message: "Request expired", retryable: false))
        }
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
