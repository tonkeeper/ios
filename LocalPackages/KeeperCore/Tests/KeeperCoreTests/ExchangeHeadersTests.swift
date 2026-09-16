import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import SwapAPI
import XCTest

/// The backend keys on-ramp provider selection on these two headers, and the generated client only
/// carries them where the spec declares them — so each API object is checked against both: the
/// header is present where it is declared and absent where it is not.
final class ExchangeHeadersTests: XCTestCase {
    private static let firebaseUserId = "firebase-user"
    private static let walletId = "wallet-1"

    // MARK: - Cross-chain swap

    func test_prepareCrossSwapRoute_sendsWalletIdAndFirebaseUserId() async throws {
        let transport = RecordingTransport()
        _ = try? await makeSwapAPI(transport).prepareCrossSwapRoute(
            routeId: "route",
            request: nil,
            walletId: Self.walletId
        )

        try assertHeaders(transport, walletId: Self.walletId, firebaseUserId: Self.firebaseUserId)
    }

    /// The asset catalogue declares `F` but no wallet header.
    func test_listCrossSwapAssets_sendsFirebaseUserIdOnly() async throws {
        let transport = RecordingTransport()
        _ = try? await makeSwapAPI(transport).listCrossSwapAssets(query: MultichainSwapAssetsQuery())

        try assertHeaders(transport, walletId: nil, firebaseUserId: Self.firebaseUserId)
    }

    // MARK: - Multichain ramp

    func test_getOnrampAsset_sendsWalletIdAndFirebaseUserId() async throws {
        let transport = RecordingTransport()
        _ = try? await makeRampAPI(transport).getOnrampAsset(assetId: "asset", walletId: Self.walletId)

        try assertHeaders(transport, walletId: Self.walletId, firebaseUserId: Self.firebaseUserId)
    }

    /// Off-ramp declares `F` but no wallet header, so the wallet must not leak onto it.
    func test_getOfframpAsset_sendsFirebaseUserIdOnly() async throws {
        let transport = RecordingTransport()
        _ = try? await makeRampAPI(transport).getOfframpAsset(assetId: "asset")

        try assertHeaders(transport, walletId: nil, firebaseUserId: Self.firebaseUserId)
    }

    // MARK: - Legacy on-ramp

    func test_getExchangeMerchants_sendsWalletIdAndFirebaseUserId() async throws {
        let transport = RecordingTransport()
        _ = try? await makeOnRampAPI(transport).getMerchants(walletId: Self.walletId)

        try assertHeaders(transport, walletId: Self.walletId, firebaseUserId: Self.firebaseUserId)
    }

    // MARK: - Absent identities

    func test_aWalletWithoutAMultichainIdSendsNoWalletHeader() async throws {
        let transport = RecordingTransport()
        _ = try? await makeRampAPI(transport).getOnrampAsset(assetId: "asset", walletId: nil)

        try assertHeaders(transport, walletId: nil, firebaseUserId: Self.firebaseUserId)
    }

    func test_missingFirebaseUserIdSendsNoHeader() async throws {
        let transport = RecordingTransport()
        _ = try? await makeSwapAPI(transport, firebaseUserId: nil).prepareCrossSwapRoute(
            routeId: "route",
            request: nil,
            walletId: Self.walletId
        )

        try assertHeaders(transport, walletId: Self.walletId, firebaseUserId: nil)
    }
}

private extension ExchangeHeadersTests {
    func assertHeaders(
        _ transport: RecordingTransport,
        walletId: String?,
        firebaseUserId: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let request = try XCTUnwrap(transport.lastRequest, file: file, line: line)
        XCTAssertEqual(
            try request.headerFields[XCTUnwrap(.init("X-Wallet-ID"))],
            walletId,
            file: file,
            line: line
        )
        XCTAssertEqual(
            try request.headerFields[XCTUnwrap(.init("F"))],
            firebaseUserId,
            file: file,
            line: line
        )
    }

    func makeClient(_ transport: RecordingTransport) -> SwapAPI.Client {
        SwapAPI.Client(serverURL: URL(string: "https://swap.tonkeeper.com")!, transport: transport)
    }

    func makeSwapAPI(
        _ transport: RecordingTransport,
        firebaseUserId: String? = firebaseUserId
    ) -> MultichainSwapAPI {
        MultichainSwapAPIImplementation(
            swapAPIClient: makeClient(transport),
            firebaseUserIdProvider: { firebaseUserId }
        )
    }

    func makeRampAPI(_ transport: RecordingTransport) -> MultichainRampAPI {
        MultichainRampAPIImplementation(
            swapAPIClient: makeClient(transport),
            appInfoProvider: StubAppInfoProvider(),
            firebaseUserIdProvider: { Self.firebaseUserId }
        )
    }

    func makeOnRampAPI(_ transport: RecordingTransport) -> OnRampAPI {
        OnRampAPIImplementation(
            swapAPIClient: makeClient(transport),
            appInfoProvider: StubAppInfoProvider(),
            firebaseUserIdProvider: { Self.firebaseUserId }
        )
    }
}

private final class RecordingTransport: ClientTransport, @unchecked Sendable {
    private(set) var lastRequest: HTTPRequest?

    func send(
        _ request: HTTPRequest,
        body _: HTTPBody?,
        baseURL _: URL,
        operationID _: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        lastRequest = request
        return (HTTPResponse(status: .internalServerError), nil)
    }
}

private struct StubAppInfoProvider: AppInfoProvider {
    var version: String {
        "1.0"
    }

    var userAgent: String {
        "Tonkeeper/1.0"
    }

    var platform: String {
        "ios"
    }

    var language: String {
        "en"
    }

    var storeCountryCode: String? {
        get async { nil }
    }

    var deviceCountryCode: String? {
        nil
    }

    var isVPNActive: Bool {
        false
    }

    var timeZoneIdentifier: String {
        "UTC"
    }
}
