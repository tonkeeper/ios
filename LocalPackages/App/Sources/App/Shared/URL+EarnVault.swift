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
        return "\(chain.rawValue)/mainnet/erc20/\(components[earnIndex + 2].lowercased())"
    }
}
