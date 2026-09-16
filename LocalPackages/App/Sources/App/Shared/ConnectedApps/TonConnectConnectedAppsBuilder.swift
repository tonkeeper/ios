import Foundation
import KeeperCore

struct TonConnectConnectedAppsBuilder {
    func connections(
        from apps: [TonConnectApp],
        metadataProvider: (TonConnectApp) -> TonConnectConnectionMetadata? = { _ in nil },
        sourceFilter: (DappConnectionSourceState) -> Bool = { _ in true }
    ) -> [TonConnectApp] {
        var seenHosts = Set<String>()
        return apps
            .filter { sourceFilter(sourceState(for: $0, metadataProvider: metadataProvider)) }
            .filter { app in
                seenHosts.insert(app.manifest.host.lowercased()).inserted
            }
    }

    func sessionConnections(
        from apps: [TonConnectApp],
        metadataProvider: (TonConnectApp) -> TonConnectConnectionMetadata? = { _ in nil },
        sourceFilter: (DappConnectionSourceState) -> Bool = { _ in true }
    ) -> [TonConnectApp] {
        apps.filter { sourceFilter(sourceState(for: $0, metadataProvider: metadataProvider)) }
            .sorted { lhs, rhs in
                switch (metadataProvider(lhs)?.sourceState.extraInfo?.createdAt, metadataProvider(rhs)?.sourceState.extraInfo?.createdAt) {
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

    func sessionConnections(
        from apps: [TonConnectApp],
        matching app: TonConnectApp,
        metadataProvider: (TonConnectApp) -> TonConnectConnectionMetadata? = { _ in nil },
        sourceFilter: (DappConnectionSourceState) -> Bool = { _ in true }
    ) -> [TonConnectApp] {
        apps.filter {
            $0.manifest.host == app.manifest.host
                && sourceFilter(sourceState(for: $0, metadataProvider: metadataProvider))
        }
    }
}

private extension TonConnectApp {
    var sortKey: String {
        "\(manifest.name.lowercased())|\(manifest.host.lowercased())|\(clientId)"
    }
}

private func sourceState(
    for app: TonConnectApp,
    metadataProvider: (TonConnectApp) -> TonConnectConnectionMetadata?
) -> DappConnectionSourceState {
    metadataProvider(app)?.sourceState ?? .unknown
}
