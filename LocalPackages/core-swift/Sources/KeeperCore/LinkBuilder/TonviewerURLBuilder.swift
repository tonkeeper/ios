import Foundation
import TonSwift

public struct TonviewerURLBuilder {
    public enum URLContent {
        case nftHistory(nft: NFT)
        case nftDetails(nft: NFT)
        case eventDetails(eventID: String)
        case accountCollectibles(address: Address)
    }

    private let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func buildURL(context: URLContent, network: Network) -> URL? {
        let resultStringURL: String
        switch context {
        case let .nftHistory(nft):
            let accountExplorer = configuration.accountExplorer(network: network)
            guard let url = accountExplorer else {
                return nil
            }
            let stringAddress = nft.address.toFriendly().toString()
            resultStringURL = url.replacingOccurrences(of: "%s", with: stringAddress)
        case let .nftDetails(nft):
            let nftOnExplorerUrl = configuration.nftOnExplorer(network: network)
            guard let url = nftOnExplorerUrl else {
                return nil
            }
            let stringAddress = nft.address.toFriendly().toString()
            resultStringURL = url.replacingOccurrences(of: "%s", with: stringAddress)
        case let .eventDetails(eventID):
            let url = configuration.transactionExplorer(network: network)
            guard let url else { return nil }
            resultStringURL = url.replacingOccurrences(of: "%s", with: eventID)
        case let .accountCollectibles(address):
            let accountExplorer = configuration.accountExplorer(network: network)
            guard let url = accountExplorer else {
                return nil
            }
            resultStringURL = url.replacingOccurrences(
                of: "%s", with: address.toFriendly(testOnly: network == .testnet).toString()
            ) + "?section=nfts"
        }

        return URL(string: resultStringURL)
    }
}
