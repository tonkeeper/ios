@testable import App
import Foundation
import LocalAuthentication
import XCTest

final class BiometryProviderErrorTests: XCTestCase {
    func test_biometryNotAvailable_onFaceID_isFaceIDDenied() {
        XCTAssertEqual(error(.biometryNotAvailable, biometryType: .faceID), .faceIDDenied)
    }

    func test_biometryNotAvailable_onTouchID_isNotAvailable() {
        XCTAssertEqual(error(.biometryNotAvailable, biometryType: .touchID), .biometryNotAvailable)
    }

    func test_biometryNotAvailable_withoutBiometry_isNotAvailable() {
        XCTAssertEqual(error(.biometryNotAvailable, biometryType: .none), .biometryNotAvailable)
    }

    func test_biometryNotEnrolled_onFaceID_isNotEnrolled() {
        XCTAssertEqual(error(.biometryNotEnrolled, biometryType: .faceID), .biometryNotEnrolled)
    }

    func test_biometryLockout_onFaceID_isLockout() {
        XCTAssertEqual(error(.biometryLockout, biometryType: .faceID), .biometryLockout)
    }

    private func error(_ code: LAError.Code, biometryType: LABiometryType) -> BiometryProvider.Error {
        BiometryProvider.Error(
            nsError: NSError(domain: LAErrorDomain, code: code.rawValue),
            biometryType: biometryType
        )
    }
}
