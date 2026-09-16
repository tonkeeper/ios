import Foundation
import KeeperCore

enum ConnectedApp {
    case tonConnect(TonConnectApp)
    case walletConnect(WalletConnectDappConnection)

    var id: String {
        switch self {
        case let .tonConnect(app):
            "tonconnect-\(app.clientId)"
        case let .walletConnect(connection):
            connection.id
        }
    }

    var name: String {
        switch self {
        case let .tonConnect(app):
            app.manifest.name
        case let .walletConnect(connection):
            connection.name
        }
    }

    var host: String {
        switch self {
        case let .tonConnect(app):
            app.manifest.host
        case let .walletConnect(connection):
            connection.host
        }
    }

    var iconURL: URL? {
        switch self {
        case let .tonConnect(app):
            app.manifest.iconUrl
        case let .walletConnect(connection):
            connection.iconURL
        }
    }

    var dappURL: URL? {
        switch self {
        case let .tonConnect(app):
            app.manifest.url
        case let .walletConnect(connection):
            connection.dappURL
        }
    }

    var chain: MultichainChain? {
        switch self {
        case .tonConnect:
            .ton
        case let .walletConnect(connection):
            connection.chain
        }
    }

    var dapp: Dapp? {
        guard let dappURL else {
            return nil
        }

        return Dapp(
            name: name,
            description: nil,
            icon: iconURL,
            poster: nil,
            url: dappURL,
            textColor: nil,
            excludeCountries: nil,
            includeCountries: nil
        )
    }

    var tonConnectApp: TonConnectApp? {
        switch self {
        case let .tonConnect(app):
            app
        default:
            nil
        }
    }

    var walletConnectConnection: WalletConnectDappConnection? {
        switch self {
        case let .walletConnect(connection):
            connection
        default:
            nil
        }
    }
}

extension ConnectedApp {
    var dappKey: String {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !host.isEmpty {
            return "host:\(host.lowercased())"
        }

        if let dappURL {
            return "url:\(dappURL.absoluteString.lowercased())"
        }

        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return "name:\(name.lowercased())"
        }

        return id
    }

    func isSameDapp(as app: ConnectedApp) -> Bool {
        dappKey == app.dappKey
    }
}

extension Sequence where Element == ConnectedApp {
    func uniqueDapps() -> [ConnectedApp] {
        var seenKeys = Set<String>()
        return filter { app in
            seenKeys.insert(app.dappKey).inserted
        }
    }
}
