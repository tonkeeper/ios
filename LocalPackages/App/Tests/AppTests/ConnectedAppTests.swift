@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

final class ConnectedAppTests: XCTestCase {
    func testUniqueDappsDeduplicatesAcrossProtocolsByHost() throws {
        let tonConnectApp = ConnectedApp.tonConnect(
            makeTonConnectApp(
                clientId: "tonconnect-client",
                name: "Example",
                host: "example.com"
            )
        )
        let walletConnectConnection = try XCTUnwrap(
            WalletConnectConnectedAppsBuilder().connections(
                from: [
                    makeWalletConnectSession(
                        topic: "walletconnect-topic",
                        walletId: "wallet",
                        name: "Example",
                        url: "https://example.com/path"
                    ),
                ],
                walletId: "wallet"
            ).first
        )
        let otherApp = ConnectedApp.tonConnect(
            makeTonConnectApp(
                clientId: "other-client",
                name: "Other",
                host: "other.example"
            )
        )

        let uniqueApps = [
            tonConnectApp,
            ConnectedApp.walletConnect(walletConnectConnection),
            otherApp,
        ].uniqueDapps()

        XCTAssertEqual(uniqueApps.map(\.id), [
            "tonconnect-tonconnect-client",
            "tonconnect-other-client",
        ])
    }
}

private extension ConnectedAppTests {
    func makeTonConnectApp(
        clientId: String,
        name: String,
        host: String
    ) -> TonConnectApp {
        TonConnectApp(
            clientId: clientId,
            manifest: TonConnectManifest(
                url: URL(string: "https://\(host)")!,
                name: name
            ),
            keyPair: KeyPair(
                publicKey: PublicKey(data: Data(repeating: 1, count: 32)),
                privateKey: PrivateKey(data: Data(repeating: 2, count: 64))
            ),
            connectionType: .remote
        )
    }

    func makeWalletConnectSession(
        topic: String,
        walletId: String?,
        name: String,
        url: String
    ) -> WalletConnectSession {
        WalletConnectSession(
            topic: topic,
            dapp: WalletConnectDapp(
                name: name,
                url: url,
                description: "Test dApp",
                iconURL: nil
            ),
            walletId: walletId,
            source: .dapp,
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }
}
