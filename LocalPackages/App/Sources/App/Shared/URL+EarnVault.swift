import Foundation
import KeeperCore

extension URL {
    func appendingEarnVaultPath(network: String, vaultId: String) -> URL {
        appendingPathComponent("earn")
            .appendingPathComponent(network)
            .appendingPathComponent(vaultId)
    }

    var earnVaultAssetId: String? {
        let components = pathComponents.filter { $0 != "/" }
        guard let earnIndex = components.lastIndex(of: "earn"),
              components.count == earnIndex + 3,
              let chain = DappBrowserAnalyticsController.assetChain(
                  from: MultichainChain(earnNetwork: components[earnIndex + 1])
              )
        else {
            return nil
        }
        let tokenType = chain == .bsc ? "bep20" : "erc20"
        return "\(chain.rawValue)/mainnet/\(tokenType)/\(components[earnIndex + 2].lowercased())"
    }
}
