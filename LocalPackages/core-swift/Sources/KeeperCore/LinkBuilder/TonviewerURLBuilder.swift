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

  public func buildURL(context: URLContent, isTestnet: Bool) -> URL? {
    let resultStringURL: String
    switch context {
    case .nftHistory(let nft):
      let accountExplorer = isTestnet
      ? configuration.accountExplorerTestnet
      : configuration.accountExplorer
      guard let url = accountExplorer else {
        return nil
      }
      let stringAddress = nft.address.toFriendly().toString()
      resultStringURL = url.replacingOccurrences(of: "%s", with: stringAddress)
    case .nftDetails(let nft):
      let nftOnExplorerUrl = isTestnet ? configuration.nftOnExplorerTestnetUrl : configuration.nftOnExplorerUrl
      guard let url = nftOnExplorerUrl else {
        return nil
      }
      let stringAddress = nft.address.toFriendly().toString()
      resultStringURL = url.replacingOccurrences(of: "%s", with: stringAddress)
    case .eventDetails(let eventID):
      let url = isTestnet ? configuration.transactionExplorerTestnet : configuration.transactionExplorer
      guard let url else { return nil }
      resultStringURL = url.replacingOccurrences(of: "%s", with: eventID)
    case .accountCollectibles(let address):
      let accountExplorer = isTestnet
      ? configuration.accountExplorerTestnet
      : configuration.accountExplorer
      guard let url = accountExplorer else {
        return nil
      }
      resultStringURL = url.replacingOccurrences(
        of: "%s", with: address.toFriendly(testOnly: isTestnet).toString()
      ) + "?section=nfts"
    }

    return URL(string: resultStringURL)
  }
}
