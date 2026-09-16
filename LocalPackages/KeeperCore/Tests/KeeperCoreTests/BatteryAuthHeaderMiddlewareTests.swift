import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import TKBatteryAPI
import XCTest

final class BatteryAuthHeaderMiddlewareTests: XCTestCase {
    func test_deviceAccessToken_travelsAsBearerAuthorization() async throws {
        let recorder = Recorder()

        try await intercept(
            authorization: BatteryAuthorization(tonProof: nil, walletId: nil, deviceAccessToken: "device-jwt"),
            recorder: recorder
        )

        XCTAssertEqual(recorder.request?.headerFields[.authorization], "Bearer device-jwt")
    }

    func test_walletAuthToken_travelsAsItsOwnHeader() async throws {
        let recorder = Recorder()

        try await intercept(
            authorization: BatteryAuthorization(
                tonProof: nil,
                walletId: "wallet-id",
                deviceAccessToken: "device-jwt",
                walletAuthToken: "wallet-auth-token"
            ),
            recorder: recorder
        )

        try XCTAssertEqual(recorder.header("X-Wallet-Authorization"), "wallet-auth-token")
        try XCTAssertEqual(recorder.header("X-Wallet-ID"), "wallet-id")
        XCTAssertEqual(recorder.request?.headerFields[.authorization], "Bearer device-jwt")
    }

    /// The backend still accepts a request without the wallet credential, so a wallet whose app key
    /// is not available must not send an empty header.
    func test_withoutWalletAuthToken_sendsNoWalletAuthorizationHeader() async throws {
        let recorder = Recorder()

        try await intercept(
            authorization: BatteryAuthorization(
                tonProof: nil,
                walletId: "wallet-id",
                deviceAccessToken: "device-jwt"
            ),
            recorder: recorder
        )

        try XCTAssertNil(recorder.header("X-Wallet-Authorization"))
        try XCTAssertEqual(recorder.header("X-Wallet-ID"), "wallet-id")
    }

    func test_tonProofAndWalletId_travelAsTheirOwnHeaders() async throws {
        let recorder = Recorder()

        try await intercept(
            authorization: BatteryAuthorization(tonProof: "ton-proof", walletId: "wallet-id", deviceAccessToken: nil),
            recorder: recorder
        )

        try XCTAssertEqual(recorder.header("X-TonConnect-Auth"), "ton-proof")
        try XCTAssertEqual(recorder.header("X-Wallet-ID"), "wallet-id")
        XCTAssertNil(recorder.request?.headerFields[.authorization])
    }

    /// A wallet that cannot build any credential still reaches the endpoints the backend answers
    /// unauthenticated, so an empty authorization must not put empty headers on the wire.
    func test_emptyAuthorization_addsNoHeaders() async throws {
        let recorder = Recorder()

        try await intercept(authorization: .none, recorder: recorder)

        try XCTAssertNil(recorder.header("X-TonConnect-Auth"))
        try XCTAssertNil(recorder.header("X-Wallet-ID"))
        XCTAssertNil(recorder.request?.headerFields[.authorization])
    }

    func test_body_isForwardedUnchanged() async throws {
        let recorder = Recorder()

        try await intercept(
            authorization: BatteryAuthorization(tonProof: nil, walletId: nil, deviceAccessToken: "device-jwt"),
            body: #"{"boc":"te6cc","proof":"deadbeef"}"#,
            recorder: recorder
        )

        XCTAssertEqual(recorder.rawBody, Data(#"{"boc":"te6cc","proof":"deadbeef"}"#.utf8))
    }
}

private extension BatteryAuthHeaderMiddlewareTests {
    func intercept(
        authorization: BatteryAuthorization,
        body: String = #"{"boc":"te6cc"}"#,
        operationID: String = Operations.sendMessage.id,
        recorder: Recorder
    ) async throws {
        let middleware = BatteryAuthHeaderMiddleware(authorization: authorization)
        _ = try await middleware.intercept(
            HTTPRequest(
                method: .post,
                scheme: nil,
                authority: nil,
                path: "/wallet/send"
            ),
            body: HTTPBody(Data(body.utf8)),
            baseURL: URL(string: "https://battery.tonkeeper.com")!,
            operationID: operationID,
            next: { request, body, _ in
                recorder.request = request
                if let body {
                    recorder.rawBody = try await Data(collecting: body, upTo: 1024)
                }
                return (HTTPResponse(status: .ok), nil)
            }
        )
    }
}

private final class Recorder: @unchecked Sendable {
    var request: HTTPRequest?
    var rawBody: Data?

    func header(_ name: String) throws -> String? {
        try request?.headerFields[XCTUnwrap(HTTPField.Name(name))]
    }
}
