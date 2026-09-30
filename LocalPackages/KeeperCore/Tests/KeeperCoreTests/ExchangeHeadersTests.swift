import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import SwapAPI
import TKFeatureFlags
import XCTest

/// The backend keys on-ramp provider selection on these two headers, and the generated client only
/// carries them where the spec declares them — so each API object is checked against both: the
/// header is present where it is declared and absent where it is not.
final class ExchangeHeadersTests: XCTestCase {
    private static let firebaseUserId = "firebase-user"
    private static let walletId = "wallet-1"
    private static let quoteRequest = MultichainSwapQuoteRequest(
        sourceAsset: "ton/mainnet/coin",
        sourceAmount: "1000000000",
        destinationAsset: "eth/mainnet/coin",
        senderAddress: "sender",
        recipientAddress: "recipient"
    )

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

    /// The swap backend picks routes by the raffle cohort, so the quote and the selected route carry
    /// the same `is_new` the raffle, banner and story endpoints receive.
    func test_createCrossSwapQuote_sendsIsNewQuery() async throws {
        let transport = RecordingTransport()
        _ = try? await makeSwapAPI(transport, isNewUser: true).createCrossSwapQuote(
            request: Self.quoteRequest,
            walletId: Self.walletId
        )
        XCTAssertEqual(try queryItems(transport)["is_new"], "true")

        _ = try? await makeSwapAPI(transport, isNewUser: false).createCrossSwapQuote(
            request: Self.quoteRequest,
            walletId: Self.walletId
        )
        XCTAssertEqual(try queryItems(transport)["is_new"], "false")
    }

    func test_prepareCrossSwapRoute_sendsIsNewQuery() async throws {
        let transport = RecordingTransport()
        _ = try? await makeSwapAPI(transport, isNewUser: true).prepareCrossSwapRoute(
            routeId: "route",
            request: nil,
            walletId: Self.walletId
        )
        XCTAssertEqual(try queryItems(transport)["is_new"], "true")

        _ = try? await makeSwapAPI(transport, isNewUser: false).prepareCrossSwapRoute(
            routeId: "route",
            request: nil,
            walletId: Self.walletId
        )
        XCTAssertEqual(try queryItems(transport)["is_new"], "false")
    }

    func test_swapRequestsReadCohortResolvedAfterClientCreation() async throws {
        let suiteName = "ExchangeHeadersTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let settings = UserDefaultsTKAppSettings(userDefaults: userDefaults)
        let transport = RecordingTransport()
        let api = MultichainSwapAPIImplementation(
            swapAPIClient: makeClient(transport),
            firebaseUserIdProvider: { Self.firebaseUserId },
            isNewUser: { settings.raffleIsNewUser ?? false }
        )

        let cohorts: [Bool?] = [nil, true, false]
        for cohort in cohorts {
            settings.raffleIsNewUser = cohort
            let expected = (cohort ?? false) ? "true" : "false"

            _ = try? await api.createCrossSwapQuote(request: Self.quoteRequest, walletId: Self.walletId)
            XCTAssertEqual(try queryItems(transport)["is_new"], expected)

            _ = try? await api.prepareCrossSwapRoute(routeId: "route", request: nil, walletId: Self.walletId)
            XCTAssertEqual(try queryItems(transport)["is_new"], expected)
        }
    }

    // MARK: - Multichain ramp

    func test_getOnrampAsset_sendsWalletIdAndFirebaseUserId() async throws {
        let transport = RecordingTransport()
        _ = try? await makeRampAPI(transport).getOnrampAsset(assetId: "asset", fiat: nil, walletId: Self.walletId)

        try assertHeaders(transport, walletId: Self.walletId, firebaseUserId: Self.firebaseUserId)
    }

    /// Payment-method availability is resolved per fiat on the backend, so the selected fiat has
    /// to reach the query; the currency-list request deliberately omits it.
    func test_getOnrampAsset_sendsFiatQueryOnlyWhenProvided() async throws {
        let transport = RecordingTransport()
        _ = try? await makeRampAPI(transport).getOnrampAsset(assetId: "asset", fiat: "EUR", walletId: nil)
        XCTAssertEqual(try queryItems(transport)["fiat"], "EUR")

        _ = try? await makeRampAPI(transport).getOnrampAsset(assetId: "asset", fiat: nil, walletId: nil)
        XCTAssertNil(try queryItems(transport)["fiat"])
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
        _ = try? await makeRampAPI(transport).getOnrampAsset(assetId: "asset", fiat: nil, walletId: nil)

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

    func queryItems(_ transport: RecordingTransport) throws -> [String: String] {
        let path = try XCTUnwrap(transport.lastRequest?.path)
        let components = try XCTUnwrap(URLComponents(string: "https://swap.tonkeeper.com\(path)"))
        return Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func makeClient(_ transport: RecordingTransport) -> SwapAPI.Client {
        SwapAPI.Client(serverURL: URL(string: "https://swap.tonkeeper.com")!, transport: transport)
    }

    func makeSwapAPI(
        _ transport: RecordingTransport,
        firebaseUserId: String? = firebaseUserId,
        isNewUser: Bool = false
    ) -> MultichainSwapAPI {
        MultichainSwapAPIImplementation(
            swapAPIClient: makeClient(transport),
            firebaseUserIdProvider: { firebaseUserId },
            isNewUser: { isNewUser }
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
