import CoreBluetooth
@testable import LedgerKit
import XCTest

final class BluetoothLedgerErrorTests: XCTestCase {
    func testSystemConnectionTimeoutBecomesRetryableTimeout() {
        let error = LedgerTransportError.fromBluetooth(NSError(domain: CBErrorDomain, code: 6))

        guard case LedgerTransportError.timeout = error else {
            return XCTFail("Unexpected error: \(error)")
        }
    }

    func testEncryptionTimeoutBecomesRetryableTimeout() {
        let error = LedgerTransportError.fromBluetooth(NSError(domain: CBErrorDomain, code: CBError.encryptionTimedOut.rawValue))

        guard case LedgerTransportError.timeout = error else {
            return XCTFail("Unexpected error: \(error)")
        }
    }

    func testLostAndFailedConnectionsBecomeRetryableDisconnections() {
        for code in [CBError.notConnected, .peripheralDisconnected, .connectionFailed] {
            let error = LedgerTransportError.fromBluetooth(NSError(domain: CBErrorDomain, code: code.rawValue))

            guard case LedgerTransportError.disconnected = error else {
                return XCTFail("Unexpected error for \(code): \(error)")
            }
        }
        guard case LedgerTransportError.disconnected = LedgerTransportError.fromBluetooth(nil) else {
            return XCTFail("A disconnect without a system error must also be retryable")
        }
    }

    func testRemovedPairingStillRequiresPairingAgain() {
        let error = LedgerTransportError.fromBluetooth(NSError(domain: CBErrorDomain, code: CBError.peerRemovedPairingInformation.rawValue))

        guard case LedgerTransportError.pairingRemoved = error else {
            return XCTFail("Unexpected error: \(error)")
        }
    }

    func testOtherErrorsArePreserved() {
        let errors = [
            NSError(domain: CBErrorDomain, code: CBError.operationNotSupported.rawValue),
            NSError(domain: "AnotherDomain", code: CBError.connectionTimeout.rawValue),
        ]
        for original in errors {
            let mapped = LedgerTransportError.fromBluetooth(original) as NSError

            XCTAssertEqual(mapped.domain, original.domain)
            XCTAssertEqual(mapped.code, original.code)
        }
    }
}
