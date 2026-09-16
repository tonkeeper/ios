import Foundation
import Testing
@testable import TronSwiftAPI

struct TronRejectionResponseTests {
    // MARK: - triggersmartcontract

    @Test
    func triggerSmartContractRejection_carriesCodeAndDecodedMessage() throws {
        let json: [String: Any] = [
            "result": [
                "result": false,
                "code": "CONTRACT_VALIDATE_ERROR",
                "message": hex("Validate TransferContract error, balance is not sufficient."),
            ],
        ]

        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.transferTransaction(from: json)
        }
        guard case let .transactionRejected(code, message) = error else {
            Issue.record("Expected transactionRejected, got \(String(describing: error))")
            return
        }
        #expect(code == "CONTRACT_VALIDATE_ERROR")
        #expect(message == "Validate TransferContract error, balance is not sufficient.")
        #expect(error?.isInsufficientTronResources == true)
    }

    /// `wallet/createtransaction` reports the same shortage as a bare `Error` string rather than a
    /// coded rejection, and the caller has to reach the same verdict either way.
    @Test
    func createTransactionShortage_isInsufficientTronResources() throws {
        let json: [String: Any] = [
            "Error": "class org.tron.core.exception.ContractValidateException : Validate TransferContract error, balance is not sufficient.",
        ]

        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.nativeTransferTransaction(from: json)
        }
        #expect(error?.isInsufficientTronResources == true)
    }

    @Test
    func unrelatedApiError_isNotInsufficientTronResources() {
        #expect(TronApi.Error.apiError(message: "Failed to create TRX transfer").isInsufficientTronResources == false)
        #expect(TronApi.Error.networkError.isInsufficientTronResources == false)
    }

    @Test
    func triggerSmartContractSuccess_parsesTransaction() throws {
        let json: [String: Any] = [
            "result": ["result": true],
            "transaction": [
                "txID": "abc",
                "raw_data_hex": "0a01",
                "raw_data": [
                    "ref_block_bytes": "00",
                    "ref_block_hash": "11",
                    "expiration": Int64(1),
                    "timestamp": Int64(2),
                ],
            ],
        ]

        let transaction = try TronApi.transferTransaction(from: json)
        #expect(transaction.txID == "abc")
    }

    @Test
    func triggerSmartContractEmptyFailure_mapsToInvalidResponse() throws {
        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.transferTransaction(from: [:])
        }
        guard case .invalidResponse = error else {
            Issue.record("Expected invalidResponse, got \(String(describing: error))")
            return
        }
    }

    // MARK: - broadcasthex

    @Test
    func broadcastSuccess_doesNotThrow() throws {
        try TronApi.validateBroadcastResponse(["result": true, "txid": "abc"])
    }

    /// `BANDWITH_ERROR` — java-tron's own spelling, which is what actually arrives on the wire.
    @Test
    func broadcastBandwidthError_carriesCodeAndMessage() throws {
        let json: [String: Any] = [
            "result": false,
            "code": "BANDWITH_ERROR",
            "message": hex("Account resource insufficient error."),
        ]

        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.validateBroadcastResponse(json)
        }
        guard case let .transactionRejected(code, message) = error else {
            Issue.record("Expected transactionRejected, got \(String(describing: error))")
            return
        }
        #expect(code == "BANDWITH_ERROR")
        #expect(message == "Account resource insufficient error.")
        #expect(error?.isInsufficientTronResources == true)
    }

    @Test
    func insufficientResourcesAreRecognizedFromMessageAlone() throws {
        let json: [String: Any] = [
            "result": false,
            "code": "CONTRACT_VALIDATE_ERROR",
            "message": hex("Account resource insufficient error."),
        ]

        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.validateBroadcastResponse(json)
        }
        #expect(error?.isInsufficientTronResources == true)
    }

    @Test
    func broadcastExpirationError_isNotMistakenForInsufficientFunds() throws {
        let json: [String: Any] = [
            "result": false,
            "code": "TRANSACTION_EXPIRATION_ERROR",
            "message": hex("Transaction expired"),
        ]

        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.validateBroadcastResponse(json)
        }
        guard case let .transactionRejected(code, _) = error else {
            Issue.record("Expected transactionRejected, got \(String(describing: error))")
            return
        }
        #expect(code == "TRANSACTION_EXPIRATION_ERROR")
        #expect(error?.isInsufficientTronResources == false)
        #expect(error?.isExpiredTronTransaction == true)
    }

    @Test
    func expirationIsRecognisedFromTheMessageWhenTheCodeIsGeneric() {
        let byMessage = TronApi.Error.transactionRejected(
            code: "CONTRACT_VALIDATE_ERROR",
            message: "Transaction expired, transaction timestamp is 1, but latest block time is 2"
        )
        #expect(byMessage.isExpiredTronTransaction)

        let unrelated = TronApi.Error.transactionRejected(code: "CONTRACT_VALIDATE_ERROR", message: "No contract!")
        #expect(!unrelated.isExpiredTronTransaction)
        #expect(!TronApi.Error.networkError.isExpiredTronTransaction)
    }

    /// The node already has the transaction we just sent — nothing failed.
    @Test
    func broadcastDuplicate_isTreatedAsSuccess() throws {
        try TronApi.validateBroadcastResponse([
            "result": false,
            "code": "DUP_TRANSACTION_ERROR",
            "message": hex("Dup transaction"),
        ])
    }

    @Test
    func broadcastFailureWithoutCode_keepsPlainMessage() throws {
        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.validateBroadcastResponse([
                "result": false,
                "message": "signature error",
            ])
        }
        guard case let .apiError(message) = error else {
            Issue.record("Expected apiError, got \(String(describing: error))")
            return
        }
        #expect(message == "signature error")
    }

    @Test
    func broadcastFailureWithoutPayload_mapsToInvalidResponse() throws {
        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.validateBroadcastResponse(["result": false])
        }
        guard case .invalidResponse = error else {
            Issue.record("Expected invalidResponse, got \(String(describing: error))")
            return
        }
    }

    // MARK: - message decoding

    @Test
    func nonHexMessage_isKeptAsIs() {
        #expect(TronRejectionResponse.decodedMessage("Account resource insufficient") == "Account resource insufficient")
    }

    @Test
    func hexLikeWordIsNotMistakenForEncodedText() {
        // "decade" is valid hex but decodes to bytes that are not readable text.
        #expect(TronRejectionResponse.decodedMessage("decade") == "decade")
    }

    @Test
    func blankMessage_isIgnored() {
        #expect(TronRejectionResponse.decodedMessage("   ") == nil)
        #expect(TronRejectionResponse.decodedMessage(nil) == nil)
    }
}

private extension TronRejectionResponseTests {
    func hex(_ value: String) -> String {
        Data(value.utf8).map { String(format: "%02x", $0) }.joined()
    }
}
