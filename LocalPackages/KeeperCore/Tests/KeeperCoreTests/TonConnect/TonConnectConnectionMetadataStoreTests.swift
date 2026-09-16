@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class TonConnectConnectionMetadataStoreTests: XCTestCase {
    func testRecordConnectionPersistsMetadata() {
        let directory = temporaryDirectory()
        let wallet = makeWallet(id: "wallet")
        let createdAt = Date(timeIntervalSince1970: 42)
        let store = makeStore(directory: directory, now: { createdAt })

        store.recordConnection(
            wallet: wallet,
            clientId: "client",
            source: .qr
        )

        let nextStore = makeStore(directory: directory)
        let metadata = TonConnectConnectionMetadata(source: .qr, createdAt: createdAt)
        XCTAssertEqual(
            nextStore.metadata(wallet: wallet, clientId: "client"),
            metadata
        )
        XCTAssertEqual(
            nextStore.metadata(wallet: wallet),
            ["client": metadata]
        )
    }

    func testDeleteConnectionRemovesMetadata() {
        let directory = temporaryDirectory()
        let wallet = makeWallet(id: "wallet")
        let store = makeStore(directory: directory)

        store.recordConnection(
            wallet: wallet,
            clientId: "client",
            source: .browser
        )
        store.deleteConnection(wallet: wallet, clientId: "client")

        XCTAssertNil(store.metadata(wallet: wallet, clientId: "client"))
    }

    func testPendingSourceCanBeConsumedByClientId() {
        let store = makeStore(directory: temporaryDirectory())
        let manifestURL = URL(string: "https://example.com/tonconnect-manifest.json")

        store.setPendingConnectionSource(
            .browser,
            clientId: "client",
            manifestURL: manifestURL
        )

        XCTAssertEqual(
            store.consumePendingConnectionSource(clientId: "client", manifestURL: manifestURL),
            .browser
        )
        XCTAssertNil(
            store.consumePendingConnectionSource(clientId: "another", manifestURL: manifestURL)
        )
    }

    func testPendingSourceCanBeConsumedByManifestHost() {
        let store = makeStore(directory: temporaryDirectory())
        let manifestURL = URL(string: "https://example.com/tonconnect-manifest.json")

        store.setPendingConnectionSource(
            .qr,
            clientId: "client",
            manifestURL: manifestURL
        )

        XCTAssertEqual(
            store.consumePendingConnectionSource(clientId: "another", manifestURL: manifestURL),
            .qr
        )
    }

    func testUnknownSourceDecodesAsUnknown() throws {
        let data = #"{"source":"unknown","createdAt":1}"#.data(using: .utf8)!

        let metadata = try JSONDecoder().decode(
            TonConnectConnectionMetadata.self,
            from: data
        )

        XCTAssertEqual(metadata.sourceState, .unknown)
    }

    func testMissingCreatedAtDecodesAsUnknown() throws {
        let data = #"{"source":"browser"}"#.data(using: .utf8)!

        let metadata = try JSONDecoder().decode(
            TonConnectConnectionMetadata.self,
            from: data
        )

        XCTAssertEqual(metadata.sourceState, .unknown)
    }
}

private extension TonConnectConnectionMetadataStoreTests {
    func temporaryDirectory() -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    func makeStore(
        directory: URL,
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> TonConnectConnectionMetadataStore {
        TonConnectConnectionMetadataStore(
            vault: FileSystemVault<TonConnectStoredConnectionMetadata, String>(
                fileManager: .default,
                directory: directory
            ),
            now: now
        )
    }

    func makeWallet(id: String) -> Wallet {
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
}
