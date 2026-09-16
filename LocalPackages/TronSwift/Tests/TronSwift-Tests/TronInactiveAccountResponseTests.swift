@testable import TronSwiftAPI
import XCTest

final class TronInactiveAccountResponseTests: XCTestCase {
    func test_getAccount_emptyObject_isNotActivated() throws {
        let response = try JSONDecoder().decode(
            WalletGetAccountResponse.self,
            from: Data("{}".utf8)
        )
        XCTAssertFalse(response.exists)
        XCTAssertNil(response.balance)
    }

    func test_getAccount_withAddress_isActivated() throws {
        let json = #"{"address":"TX1vTqTiDUdS5tDgnYepNvFCeSTcKXWVXc","balance":0,"create_time":1}"#
        let response = try JSONDecoder().decode(
            WalletGetAccountResponse.self,
            from: Data(json.utf8)
        )
        XCTAssertTrue(response.exists)
    }

    func test_isAccountMissing_looksAtTheMessageOnly() {
        XCTAssertFalse(TronRejectionCode.isAccountMissing(message: nil))
        XCTAssertTrue(TronRejectionCode.isAccountMissing(message: "Account does not exist!"))
        XCTAssertTrue(TronRejectionCode.isAccountMissing(message: "Validate error: Account does not exist!"))
        XCTAssertFalse(TronRejectionCode.isAccountMissing(message: "Witness permission error"))
    }

    func test_nativeTransferRejection_withMissingAccountMessage_isInactiveTronAccount() {
        let json: [String: Any] = [
            "Error": "class org.tron.core.exception.ContractValidateException : Account does not exist!",
        ]

        XCTAssertThrowsError(try TronApi.nativeTransferTransaction(from: json)) { error in
            XCTAssertTrue((error as? TronApi.Error)?.isInactiveTronAccount == true)
        }
    }

    func test_broadcastRejection_withMissingAccountMessage_isInactiveTronAccount() {
        let json: [String: Any] = [
            "result": false,
            "code": "CONTRACT_VALIDATE_ERROR",
            "message": Data("Validate TransferContract error, Account does not exist!".utf8).hexString(),
        ]

        XCTAssertThrowsError(try TronApi.validateBroadcastResponse(json)) { error in
            XCTAssertTrue((error as? TronApi.Error)?.isInactiveTronAccount == true)
        }
    }

    func test_broadcastRejection_withOtherMessage_isNotInactiveTronAccount() {
        let json: [String: Any] = [
            "result": false,
            "code": "CONTRACT_VALIDATE_ERROR",
            "message": Data("Contract validate error : No contract!".utf8).hexString(),
        ]

        XCTAssertThrowsError(try TronApi.validateBroadcastResponse(json)) { error in
            XCTAssertFalse((error as? TronApi.Error)?.isInactiveTronAccount == true)
        }
    }
}
