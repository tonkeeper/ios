import Foundation
import Testing
@testable import TronSwiftAPI

struct NativeTransferResponseTests {
    @Test
    func createtransactionErrorPayload_mapsToApiError() throws {
        let json: [String: Any] = [
            "Error": "class org.tron.core.exception.ContractValidateException : Validate TransferContract error, balance is not sufficient.",
        ]

        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.nativeTransferTransaction(from: json)
        }
        guard case let .apiError(message) = error else {
            Issue.record("Expected apiError, got \(String(describing: error))")
            return
        }
        #expect(message.contains("balance is not sufficient"))
    }

    @Test
    func createtransactionMessagePayload_mapsToApiError() throws {
        let json: [String: Any] = [
            "message": "Failed to create TRX transfer",
        ]

        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.nativeTransferTransaction(from: json)
        }
        guard case let .apiError(message) = error else {
            Issue.record("Expected apiError, got \(String(describing: error))")
            return
        }
        #expect(message == "Failed to create TRX transfer")
    }

    @Test
    func createtransactionEmptyFailure_mapsToInvalidResponse() throws {
        let error = #expect(throws: TronApi.Error.self) {
            try TronApi.nativeTransferTransaction(from: [:])
        }
        guard case .invalidResponse = error else {
            Issue.record("Expected invalidResponse, got \(String(describing: error))")
            return
        }
    }

    @Test
    func createtransactionSuccess_parsesTransaction() throws {
        let json: [String: Any] = [
            "txID": "abc",
            "raw_data_hex": "0a01",
            "raw_data": [
                "ref_block_bytes": "00",
                "ref_block_hash": "11",
                "expiration": Int64(1),
                "timestamp": Int64(2),
            ],
        ]

        let transaction = try TronApi.nativeTransferTransaction(from: json)
        #expect(transaction.txID == "abc")
        #expect(transaction.rawDataHex == "0a01")
    }
}
