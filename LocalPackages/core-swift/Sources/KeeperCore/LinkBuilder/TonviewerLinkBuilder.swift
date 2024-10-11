import Foundation

public struct TonviewerLinkBuilder {

  public enum TonviewerURLContext {
    case nftHistory(nft: NFT)
    case nftDetails(nft: NFT)
    case eventDetails(eventID: String)
  }

  private let configurationStore: ConfigurationStore

  public init(configurationStore: ConfigurationStore) {
    self.configurationStore = configurationStore
  }

  public func buildLink(context: TonviewerURLContext, isTestnet: Bool) -> URL? {
    let configuration = configurationStore.getConfiguration()

    let resultStringURL: String
    switch context {
    case .nftHistory(let nft):
      let accountExplorer = isTestnet ? configuration.accountExplorerTestnet : configuration.accountExplorer
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
    }

    return URL(string: resultStringURL)
  }
}
