import Foundation
import KeeperCore

struct WalletConnectConnectedAppsBuilder {
    func connections(
        from sessions: [WalletConnectSession],
        walletId: String,
        sourceFilter: (DappConnectionSourceState) -> Bool = { _ in true }
    ) -> [WalletConnectDappConnection] {
        let walletSessions = sessions.filter {
            $0.walletId == walletId
                && sourceFilter($0.sourceState)
        }
        let groupedSessions = Dictionary(
            grouping: walletSessions,
            by: WalletConnectDappKey.init(session:)
        )
        return groupedSessions.compactMap { key, sessions in
            WalletConnectDappConnection(key: key, sessions: sessions)
        }
        .sorted { lhs, rhs in
            lhs.sortKey < rhs.sortKey
        }
    }

    func sessionConnections(
        from sessions: [WalletConnectSession],
        walletId: String,
        sourceFilter: (DappConnectionSourceState) -> Bool = { _ in true }
    ) -> [WalletConnectDappConnection] {
        sessions
            .filter {
                $0.walletId == walletId
                    && sourceFilter($0.sourceState)
            }
            .compactMap { session in
                WalletConnectDappConnection(
                    key: WalletConnectDappKey(topic: session.topic),
                    sessions: [session]
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.createdAt, rhs.createdAt) {
                case let (lhsCreatedAt?, rhsCreatedAt?) where lhsCreatedAt != rhsCreatedAt:
                    return lhsCreatedAt > rhsCreatedAt
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.sortKey < rhs.sortKey
                }
            }
    }
}

struct WalletConnectDappConnection {
    private let key: WalletConnectDappKey
    let sessions: [WalletConnectSession]
    let representativeSession: WalletConnectSession

    fileprivate init?(key: WalletConnectDappKey, sessions: [WalletConnectSession]) {
        let sortedSessions = sessions.sorted { $0.topic < $1.topic }
        guard let representativeSession = sortedSessions.first else {
            return nil
        }
        self.key = key
        self.sessions = sortedSessions
        self.representativeSession = representativeSession
    }

    var id: String {
        "walletconnect-\(key.value)"
    }

    var topics: [String] {
        sessions.map(\.topic)
    }

    var name: String {
        let name = trimmed(representativeSession.dapp.name)
        return name.isEmpty ? host : name
    }

    var host: String {
        dappHost(representativeSession.dapp)
    }

    var chain: MultichainChain? {
        let distinctChains = Set(sessions.flatMap(\.chains))
        guard distinctChains.count == 1, let chain = distinctChains.first else {
            return nil
        }
        return chain.multichainChain
    }

    var iconURL: URL? {
        representativeSession.dapp.iconURL.flatMap { absoluteDappURL(fromURLString: $0) }
    }

    var dappURL: URL? {
        absoluteDappURL(fromURLString: representativeSession.dapp.url)
    }

    var sourceState: DappConnectionSourceState {
        representativeSession.sourceState
    }

    var extraInfo: DappConnectionExtraInfo? {
        sourceState.extraInfo
    }

    var createdAt: Date? {
        extraInfo?.createdAt
    }

    var sortKey: String {
        "\(name.lowercased())|\(host.lowercased())|\(id)"
    }
}

private struct WalletConnectDappKey: Hashable {
    let value: String

    init(topic: String) {
        value = "topic:\(topic)"
    }

    init(session: WalletConnectSession) {
        if let host = dappHost(fromURLString: session.dapp.url) {
            value = "host:\(host.lowercased())"
            return
        }

        let url = trimmed(session.dapp.url)
        if !url.isEmpty {
            value = "url:\(url.lowercased())"
            return
        }

        let name = trimmed(session.dapp.name)
        if !name.isEmpty {
            value = "name:\(name.lowercased())"
            return
        }

        value = "topic:\(session.topic)"
    }
}

private func dappHost(_ dapp: WalletConnectDapp) -> String {
    if let host = dappHost(fromURLString: dapp.url) {
        return host
    }

    let url = trimmed(dapp.url)
    if !url.isEmpty {
        return url
    }

    let name = trimmed(dapp.name)
    return name.isEmpty ? "dApp" : name
}

private func dappHost(fromURLString urlString: String) -> String? {
    guard let url = absoluteDappURL(fromURLString: urlString),
          let host = url.host,
          !host.isEmpty
    else {
        return nil
    }

    return host
}

private func absoluteDappURL(fromURLString urlString: String) -> URL? {
    let urlString = trimmed(urlString)
    guard !urlString.isEmpty else {
        return nil
    }

    if let url = URL(string: urlString), url.scheme != nil {
        return url
    }

    return URL(string: "https://\(urlString)")
}

private func trimmed(_ string: String) -> String {
    string.trimmingCharacters(in: .whitespacesAndNewlines)
}
