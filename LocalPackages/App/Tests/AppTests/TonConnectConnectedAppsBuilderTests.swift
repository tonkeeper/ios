@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

final class TonConnectConnectedAppsBuilderTests: XCTestCase {
    func testConnectionsFilterBrowserSourcesAndDeduplicateDapps() {
        let metadataByClientId = [
            "qr": metadata(source: .qr),
            "dapp-a": metadata(source: .dapp),
            "dapp-b": metadata(source: .dapp),
            "unknown": TonConnectConnectionMetadata(sourceState: .unknown),
            "browser-missing-date": TonConnectConnectionMetadata(
                sourceState: DappConnectionSourceState(source: .browser, createdAt: nil)
            ),
            "deeplink": metadata(source: .deeplink),
        ]

        let connections = TonConnectConnectedAppsBuilder().connections(
            from: [
                makeApp(clientId: "qr", name: "QR", host: "qr.example"),
                makeApp(clientId: "dapp-a", name: "Example", host: "example.com"),
                makeApp(clientId: "dapp-b", name: "Example", host: "example.com"),
                makeApp(clientId: "unknown", name: "Legacy", host: "legacy.example"),
                makeApp(clientId: "browser-missing-date", name: "Legacy", host: "legacy-source.example"),
                makeApp(clientId: "deeplink", name: "Deeplink", host: "deeplink.example"),
                makeApp(clientId: "missing", name: "Missing", host: "missing.example"),
            ],
            metadataProvider: { metadataByClientId[$0.clientId] },
            sourceFilter: isBrowserConnectedSource
        )

        XCTAssertEqual(connections.map(\.clientId), [
            "dapp-a",
            "unknown",
            "browser-missing-date",
            "missing",
        ])
    }

    func testSessionConnectionsForDisconnectKeepOnlyMatchingBrowserSourceSessions() {
        let metadataByClientId = [
            "dapp-a": metadata(source: .dapp),
            "unknown": TonConnectConnectionMetadata(sourceState: .unknown),
            "qr": metadata(source: .qr),
            "other": metadata(source: .dapp),
        ]
        let selectedApp = makeApp(clientId: "dapp-a", name: "Example", host: "example.com")

        let sessions = TonConnectConnectedAppsBuilder().sessionConnections(
            from: [
                selectedApp,
                makeApp(clientId: "unknown", name: "Example", host: "example.com"),
                makeApp(clientId: "qr", name: "Example", host: "example.com"),
                makeApp(clientId: "other", name: "Other", host: "other.example"),
            ],
            matching: selectedApp,
            metadataProvider: { metadataByClientId[$0.clientId] },
            sourceFilter: isBrowserConnectedSource
        )

        XCTAssertEqual(sessions.map(\.clientId), [
            "dapp-a",
            "unknown",
        ])
    }

    func testSessionConnectionsKeepMultipleSessionsForSameDapp() {
        let metadataByClientId = [
            "client-a": TonConnectConnectionMetadata(
                source: .qr,
                createdAt: Date(timeIntervalSince1970: 1)
            ),
            "client-b": TonConnectConnectionMetadata(
                source: .qr,
                createdAt: Date(timeIntervalSince1970: 2)
            ),
        ]

        let connections = TonConnectConnectedAppsBuilder().sessionConnections(
            from: [
                makeApp(
                    clientId: "client-a",
                    name: "Example",
                    host: "example.com"
                ),
                makeApp(
                    clientId: "client-b",
                    name: "Example",
                    host: "example.com"
                ),
            ],
            metadataProvider: { metadataByClientId[$0.clientId] }
        )

        XCTAssertEqual(connections.map(\.clientId), [
            "client-b",
            "client-a",
        ])
        XCTAssertEqual(connections.map(ConnectedApp.tonConnect).map(\.id), [
            "tonconnect-client-b",
            "tonconnect-client-a",
        ])
    }

    func testSessionConnectionsSortMissingDatesByDapp() {
        let connections = TonConnectConnectedAppsBuilder().sessionConnections(
            from: [
                makeApp(clientId: "client-b", name: "Beta", host: "beta.example"),
                makeApp(clientId: "client-a", name: "Alpha", host: "alpha.example"),
            ]
        )

        XCTAssertEqual(connections.map(\.clientId), [
            "client-a",
            "client-b",
        ])
    }
}

private extension TonConnectConnectedAppsBuilderTests {
    func metadata(source: DappConnectionSource) -> TonConnectConnectionMetadata {
        TonConnectConnectionMetadata(
            source: source,
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }

    func isBrowserConnectedSource(_ sourceState: DappConnectionSourceState) -> Bool {
        switch sourceState {
        case let .known(extraInfo):
            return extraInfo.source == .dapp
        case .unknown:
            return true
        }
    }

    func makeApp(
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
}
