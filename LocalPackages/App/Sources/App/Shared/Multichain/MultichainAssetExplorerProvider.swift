import Foundation
import KeeperCore

struct MultichainAssetExplorerProvider {
    struct AssetExplorer {
        enum Destination: Equatable {
            case tonviewerDetails
            case url(URL)
        }

        let destination: Destination
        let browserTitle: String
    }

    private let explorersProvider: () -> [BootConfiguration.ChainExplorer]

    init(explorersProvider: @escaping () -> [BootConfiguration.ChainExplorer]) {
        self.explorersProvider = explorersProvider
    }

    func assetExplorer(for assetId: String) -> AssetExplorer? {
        guard
            let components = AssetIdComponents(assetId: assetId),
            let chain = MultichainChain(assetIdChain: components.chain),
            let explorer = explorersProvider().first(where: {
                MultichainChain(assetIdChain: $0.chain) == chain
            })
        else {
            return nil
        }

        if case let .asset(_, _, _, address) = components,
           let tokenURL = explorer.tokenURL,
           let url = URL(string: tokenURL.replacingOccurrences(of: Constants.tokenAddressPlaceholder, with: address))
        {
            return AssetExplorer(destination: .url(url), browserTitle: explorer.name)
        }

        // A native coin has no contract address to substitute, so TON keeps the wallet-scoped
        // Tonviewer page the token details configurator builds.
        guard case .coin = components, chain == .ton else {
            return nil
        }
        return AssetExplorer(destination: .tonviewerDetails, browserTitle: explorer.name)
    }
}

private extension MultichainAssetExplorerProvider {
    enum Constants {
        static let tokenAddressPlaceholder = "{token_address}"
    }
}
