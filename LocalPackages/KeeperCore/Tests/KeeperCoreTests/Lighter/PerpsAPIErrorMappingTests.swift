import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import TKPerpsAPI
import XCTest

final class PerpsAPIErrorMappingTests: XCTestCase {
    /// The generated client throws on a body it cannot decode; the deposit must still read as refused.
    func testARefusalWithAnUnreadableBodyKeepsItsStatus() async {
        let error = await openDepositFailure(status: .conflict, contentType: "text/html", body: "<html>conflict</html>")

        guard case let .badStatus(failure) = error else {
            return XCTFail("unexpected error: \(String(describing: error))")
        }
        XCTAssertEqual(failure.httpStatus, 409)
        XCTAssertNil(failure.code)
    }

    /// An answer that arrived but could not be read is not a refusal: the deposit may have been recorded.
    func testAnUnreadableRecordIsNotARefusal() async {
        let error = await openDepositFailure(status: .ok, contentType: "application/json", body: "{")

        guard case .transport = error else {
            return XCTFail("unexpected error: \(String(describing: error))")
        }
    }

    func testAnAmountTooLowRefusalCarriesTheMinimumInDollars() async {
        let body = #"{"code":"validation_error","retryable":false,"details":{"reason":"amount_too_low","min_usd_amount":"2.53","expected_amount":"0.84"}}"#
        let transport = StubTransport(status: .badRequest, contentType: "application/json", body: body)
        let api = PerpsAPIImplementation { _ in
            Client(serverURL: URL(string: "https://perps.tonkeeper.com")!, transport: transport)
        }
        do {
            _ = try await api.quoteDeposit(
                walletId: "wallet",
                request: .init(source_asset: "ton/mainnet/coin", source_amount: "1600000000", sender_address: "UQ", destination_address: "0x1")
            )
            XCTFail("expected the quote to be refused")
        } catch let PerpsAPIError.badStatus(failure) {
            XCTAssertEqual(failure.reason, "amount_too_low")
            XCTAssertEqual(failure.minUsdAmount, "2.53")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testWithdrawalRateLimitSurvivesSendAndQuoteResponses() async {
        for status in [HTTPResponse.Status.badRequest, .conflict, .tooManyRequests, .serviceUnavailable] {
            for body in [
                #"{"code":"withdrawal_rate_limited","retryable":false}"#,
                #"{"code":"validation_error","details":{"reason":"withdrawal_rate_limited"},"retryable":false}"#,
            ] {
                let transport = StubTransport(status: status, contentType: "application/json", body: body)
                let api = PerpsAPIImplementation { _ in
                    Client(serverURL: URL(string: "https://perps.tonkeeper.com")!, transport: transport)
                }
                do {
                    _ = try await api.sendTransactions(walletId: "wallet", operationId: nil, transactions: [])
                    XCTFail("expected the send to be refused")
                } catch {
                    XCTAssertEqual(PerpsWithdrawService.message(for: error), .withdrawalRateLimited, "status=\(status)")
                }
                do {
                    _ = try await api.quoteWithdraw(walletId: "wallet", request: .init(destination_asset: "ton/mainnet/coin", amount: "1000000", recipient_address: "UQ"))
                    XCTFail("expected the quote to be refused")
                } catch {
                    XCTAssertEqual(PerpsWithdrawService.message(for: error), .withdrawalRateLimited, "status=\(status)")
                }
            }
        }
    }

    func testRetryableErrorsAreNotDefinitiveWithdrawalRateLimitRefusals() {
        let error = PerpsAPIError.badStatus(.init(httpStatus: 503, code: "withdrawal_rate_limited", message: nil, retryable: true, reason: nil))
        XCTAssertFalse(error.isWithdrawalRateLimited)
        XCTAssertEqual(PerpsWithdrawService.message(for: error), .serviceUnavailable)
    }

    private func openDepositFailure(status: HTTPResponse.Status, contentType: String, body: String) async -> PerpsAPIError? {
        let transport = StubTransport(status: status, contentType: contentType, body: body)
        let api = PerpsAPIImplementation { _ in
            Client(serverURL: URL(string: "https://perps.tonkeeper.com")!, transport: transport)
        }
        do {
            _ = try await api.openDeposit(
                walletId: "wallet",
                request: .init(operation_id: "op-1", asset_id: "asset", amount: "1")
            )
            XCTFail("expected the request to fail")
            return nil
        } catch let error as PerpsAPIError {
            return error
        } catch {
            XCTFail("expected a perps error, got \(error)")
            return nil
        }
    }
}

private struct StubTransport: ClientTransport {
    let status: HTTPResponse.Status
    let contentType: String
    let body: String

    func send(
        _: HTTPRequest,
        body _: HTTPBody?,
        baseURL _: URL,
        operationID _: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        (HTTPResponse(status: status, headerFields: [.contentType: contentType]), HTTPBody(body))
    }
}
