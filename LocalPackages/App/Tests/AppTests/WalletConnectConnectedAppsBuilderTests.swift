@testable import App
@testable import KeeperCore
import XCTest

final class WalletConnectConnectedAppsBuilderTests: XCTestCase {
    func testConnectionsFilterBrowserSourcesBeforeGrouping() throws {
        let connections = WalletConnectConnectedAppsBuilder().connections(
            from: [
                makeSession(
                    topic: "dapp-topic",
                    walletId: "wallet",
                    name: "Example",
                    url: "https://example.com",
                    source: .dapp,
                    createdAt: Date(timeIntervalSince1970: 1)
                ),
                makeSession(
                    topic: "unknown-topic",
                    walletId: "wallet",
                    name: "Example",
                    url: "https://example.com/path",
                    source: nil
                ),
                makeSession(
                    topic: "browser-topic",
                    walletId: "wallet",
                    name: "Example",
                    url: "https://example.com/hidden",
                    source: .browser,
                    createdAt: Date(timeIntervalSince1970: 1)
                ),
                makeSession(
                    topic: "missing-source-topic",
                    walletId: "wallet",
                    name: "Legacy",
                    url: "https://legacy.example",
                    source: nil
                ),
                makeSession(
                    topic: "browser-missing-date-topic",
                    walletId: "wallet",
                    name: "Legacy",
                    url: "https://legacy.example/path",
                    source: .browser
                ),
            ],
            walletId: "wallet",
            sourceFilter: isBrowserConnectedSource
        )

        XCTAssertEqual(connections.map(\.host), ["example.com", "legacy.example"])
        let exampleConnection = try XCTUnwrap(connections.first { $0.host == "example.com" })
        XCTAssertEqual(exampleConnection.topics, ["dapp-topic", "unknown-topic"])
    }

    func testGroupsCurrentWalletSessionsByDapp() throws {
        let connections = WalletConnectConnectedAppsBuilder().connections(
            from: [
                makeSession(
                    topic: "topic-b",
                    walletId: "wallet",
                    name: "Example",
                    url: "https://example.com/swap"
                ),
                makeSession(
                    topic: "topic-a",
                    walletId: "wallet",
                    name: "Example",
                    url: "https://example.com"
                ),
                makeSession(
                    topic: "other-wallet-topic",
                    walletId: "other-wallet",
                    name: "Example",
                    url: "https://example.com"
                ),
                makeSession(
                    topic: "missing-wallet-topic",
                    walletId: nil,
                    name: "Example",
                    url: "https://example.com"
                ),
                makeSession(
                    topic: "topic-c",
                    walletId: "wallet",
                    name: "Another",
                    url: "https://another.example"
                ),
            ],
            walletId: "wallet"
        )

        XCTAssertEqual(connections.map(\.host), ["another.example", "example.com"])
        let exampleConnection = try XCTUnwrap(connections.first { $0.host == "example.com" })
        XCTAssertEqual(exampleConnection.name, "Example")
        XCTAssertEqual(exampleConnection.id, "walletconnect-host:example.com")
        XCTAssertEqual(exampleConnection.topics, ["topic-a", "topic-b"])
    }

    func testConnectedAppUsesSessionDappURL() throws {
        let connection = try XCTUnwrap(
            WalletConnectConnectedAppsBuilder().connections(
                from: [
                    makeSession(
                        topic: "topic",
                        walletId: "wallet",
                        name: "Example",
                        url: "example.com/swap"
                    ),
                ],
                walletId: "wallet"
            ).first
        )
        let connectedApp = ConnectedApp.walletConnect(connection)

        XCTAssertEqual(connectedApp.dapp?.url.absoluteString, "https://example.com/swap")
    }

    func testSessionConnectionsKeepMultipleSessionsForSameDapp() {
        let connections = WalletConnectConnectedAppsBuilder().sessionConnections(
            from: [
                makeSession(
                    topic: "topic-a",
                    walletId: "wallet",
                    name: "Example",
                    url: "https://example.com",
                    createdAt: Date(timeIntervalSince1970: 1)
                ),
                makeSession(
                    topic: "topic-b",
                    walletId: "wallet",
                    name: "Example",
                    url: "https://example.com",
                    createdAt: Date(timeIntervalSince1970: 2)
                ),
            ],
            walletId: "wallet"
        )

        XCTAssertEqual(connections.map(\.id), [
            "walletconnect-topic:topic-b",
            "walletconnect-topic:topic-a",
        ])
        XCTAssertEqual(connections.map(\.topics), [
            ["topic-b"],
            ["topic-a"],
        ])
    }

    func testSessionConnectionsIgnoreOtherWalletSessions() {
        let connections = WalletConnectConnectedAppsBuilder().sessionConnections(
            from: [
                makeSession(
                    topic: "topic",
                    walletId: "other-wallet",
                    name: "Example",
                    url: "https://example.com"
                ),
            ],
            walletId: "wallet"
        )

        XCTAssertTrue(connections.isEmpty)
    }
}

private extension WalletConnectConnectedAppsBuilderTests {
    func isBrowserConnectedSource(_ sourceState: DappConnectionSourceState) -> Bool {
        switch sourceState {
        case let .known(extraInfo):
            return extraInfo.source == .dapp
        case .unknown:
            return true
        }
    }

    func makeSession(
        topic: String,
        walletId: String?,
        name: String,
        url: String,
        source: DappConnectionSource? = .deeplink,
        createdAt: Date? = nil
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
            sourceState: DappConnectionSourceState(
                source: source,
                createdAt: createdAt
            )
        )
    }
}
