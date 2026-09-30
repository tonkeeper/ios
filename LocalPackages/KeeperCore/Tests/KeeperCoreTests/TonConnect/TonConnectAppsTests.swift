@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class TonConnectAppsTests: XCTestCase {
    func testAddAppKeepsMultipleSessionsForSameHost() {
        let apps = TonConnectApps(apps: [])
            .addApp(makeApp(clientId: "client-a", host: "example.com"))
            .addApp(makeApp(clientId: "client-b", host: "example.com"))

        XCTAssertEqual(apps.apps.map(\.clientId), [
            "client-a",
            "client-b",
        ])
    }

    func testAddAppReplacesSameSession() {
        let apps = TonConnectApps(apps: [])
            .addApp(makeApp(clientId: "client", host: "old.example"))
            .addApp(makeApp(clientId: "client", host: "new.example"))

        XCTAssertEqual(apps.apps.map(\.manifest.host), ["new.example"])
    }

    func testRemoveAppByClientIdKeepsOtherSessionsForSameHost() {
        let apps = TonConnectApps(apps: [
            makeApp(clientId: "client-a", host: "example.com"),
            makeApp(clientId: "client-b", host: "example.com"),
        ])
        .removeApp(clientId: "client-a")

        XCTAssertEqual(apps.apps.map(\.clientId), ["client-b"])
    }

    func testTonConnectAppDecodesIgnoringConnectionMetadataFields() throws {
        let app = makeApp(
            clientId: "client",
            host: "example.com"
        )
        let data = try JSONEncoder().encode(app)
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        dictionary["source"] = "qr"
        dictionary["createdAt"] = 1
        let metadataData = try JSONSerialization.data(withJSONObject: dictionary)

        let decoded = try JSONDecoder().decode(TonConnectApp.self, from: metadataData)

        XCTAssertEqual(decoded.connectionType, .remote)
        XCTAssertNil(decoded.manifestURL)
        XCTAssertFalse(decoded.hasVerifiedManifestOrigin)
    }

    func testLegacyAppWithoutManifestURLIsPreservedWithoutBeingVerified() {
        let app = makeApp(clientId: "client", host: "example.com")

        XCTAssertFalse(app.hasVerifiedManifestOrigin)
        XCTAssertTrue(app.shouldPreserveStoredConnection)
    }

    func testAppWithMatchingManifestOriginIsVerified() {
        let app = makeApp(
            clientId: "client",
            host: "example.com",
            manifestURL: URL(string: "https://EXAMPLE.com:443/tonconnect-manifest.json")
        )

        XCTAssertTrue(app.hasVerifiedManifestOrigin)
        XCTAssertTrue(app.shouldPreserveStoredConnection)
    }

    func testAppWithMismatchedManifestOriginIsNotVerified() {
        let app = makeApp(
            clientId: "client",
            host: "legitimate.example",
            manifestURL: URL(string: "https://attacker.example/tonconnect-manifest.json")
        )

        XCTAssertFalse(app.hasVerifiedManifestOrigin)
        XCTAssertFalse(app.shouldPreserveStoredConnection)
    }

    func testManifestURLRoundTripsThroughPersistenceEncoding() throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://example.com/tonconnect-manifest.json"))
        let app = makeApp(
            clientId: "client",
            host: "example.com",
            manifestURL: manifestURL
        )

        let data = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(TonConnectApp.self, from: data)

        XCTAssertEqual(decoded.manifestURL, manifestURL)
        XCTAssertTrue(decoded.hasVerifiedManifestOrigin)
    }

    func testRecordConnectionMetadataStoresPendingSourceByActualClientId() {
        let wallet = makeWallet(id: "wallet")
        let createdAt = Date(timeIntervalSince1970: 42)
        let store = makeStore(now: { createdAt })
        let manifestURL = URL(string: "https://example.com/tonconnect-manifest.json")

        store.setPendingConnectionSource(
            .dapp,
            clientId: "provisional-client",
            manifestURL: manifestURL
        )

        let source = store.recordConnectionMetadata(
            wallet: wallet,
            clientId: "actual-session",
            manifestURL: manifestURL,
            notifyObservers: false
        )

        XCTAssertEqual(source, .dapp)
        XCTAssertEqual(
            store.connectionMetadata(wallet: wallet, clientId: "actual-session"),
            TonConnectConnectionMetadata(source: .dapp, createdAt: createdAt)
        )
        XCTAssertNil(store.connectionMetadata(wallet: wallet, clientId: "provisional-client"))
    }

    func testRecordConnectionMetadataFallsBackToDeeplinkByActualClientId() {
        let wallet = makeWallet(id: "wallet")
        let createdAt = Date(timeIntervalSince1970: 43)
        let store = makeStore(now: { createdAt })

        let source = store.recordConnectionMetadata(
            wallet: wallet,
            clientId: "actual-session",
            manifestURL: nil,
            notifyObservers: false
        )

        XCTAssertEqual(source, .deeplink)
        XCTAssertEqual(
            store.connectionMetadata(wallet: wallet, clientId: "actual-session"),
            TonConnectConnectionMetadata(source: .deeplink, createdAt: createdAt)
        )
    }

    private func makeStore(
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> TonConnectAppsStore {
        TonConnectAppsStore(
            tonConnectService: TonConnectServiceMock(),
            connectionMetadataStore: TonConnectConnectionMetadataStore(
                vault: FileSystemVault<TonConnectStoredConnectionMetadata, String>(
                    fileManager: .default,
                    directory: temporaryDirectory()
                ),
                now: now
            )
        )
    }

    private func makeWallet(id: String) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        let publicKey = PublicKey(data: Data(publicKeyData.prefix(32)))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }

    private func temporaryDirectory() -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}

private extension TonConnectAppsTests {
    func makeApp(
        clientId: String,
        host: String,
        manifestURL: URL? = nil
    ) -> TonConnectApp {
        TonConnectApp(
            clientId: clientId,
            manifest: TonConnectManifest(
                url: URL(string: "https://\(host)")!,
                name: "Example"
            ),
            manifestURL: manifestURL,
            keyPair: KeyPair(
                publicKey: PublicKey(data: Data(repeating: 1, count: 32)),
                privateKey: PrivateKey(data: Data(repeating: 2, count: 64))
            ),
            connectionType: .remote
        )
    }
}

private final class TonConnectServiceMock: TonConnectService {
    func loadAppManifest(parameters: TonConnectParameters) async -> Result<TonConnectManifest, TonConnectManifestError> {
        fatalError("Unused")
    }

    func buildConnectEventSuccessResponse(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply,
        keeperVersion: String
    ) async throws -> TonConnect.ConnectEventSuccess {
        fatalError("Unused")
    }

    func encryptSuccessResponse(
        _ successResponse: TonConnect.ConnectEventSuccess,
        parameters: TonConnectParameters,
        sessionCrypto: TonConnectSessionCrypto
    ) throws -> String {
        fatalError("Unused")
    }

    func buildReconnectConnectEventSuccessResponse(
        wallet: Wallet,
        manifest: TonConnectManifest,
        keeperVersion: String
    ) throws -> TonConnect.ConnectEventSuccess {
        fatalError("Unused")
    }

    func storeConnectedApp(
        wallet: Wallet,
        sessionCrypto: TonConnectSessionCrypto,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        connectionType: TonConnectApp.ConnectionType
    ) throws {}

    func confirmConnectionRequest(
        body: String,
        sessionCrypto: TonConnectSessionCrypto,
        parameters: TonConnectParameters
    ) async throws {}

    func getConnectedApps(forWallet wallet: Wallet) throws -> TonConnectApps {
        TonConnectApps(apps: [])
    }

    func disconnectApp(_ app: TonConnectApp, wallet: Wallet) throws {}

    func disconnectApp(_ clientId: String, wallet: Wallet) throws {}

    func disconnectApp(_ idx: Int, wallet: Wallet) throws {}

    func cancelRequest(
        appRequest: TonConnect.SendTransactionRequest,
        app: TonConnectApp
    ) async throws {}

    func confirmRequest(
        boc: String,
        appRequest: TonConnect.SendTransactionRequest,
        app: TonConnectApp
    ) async throws {}

    func cancelSignRequest(
        appRequest: TonConnect.SignDataRequest,
        app: TonConnectApp
    ) async throws {}

    func confirmSignRequest(
        signed: SignedDataResult,
        appRequest: TonConnect.SignDataRequest,
        app: TonConnectApp
    ) async throws {}

    func confirmDisconnectRequest(
        appRequest: TonConnect.DisconnectRequest,
        app: TonConnectApp
    ) async throws {}

    func getLastEventId() throws -> String {
        ""
    }

    func saveLastEventId(_ lastEventId: String) throws {}

    func loadManifest(url: URL) async throws -> TonConnectManifest {
        fatalError("Unused")
    }
}
