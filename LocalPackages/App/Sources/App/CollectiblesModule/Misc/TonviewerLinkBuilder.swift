import Foundation
import KeeperCore

struct TonviewerLinkBuilder {

  enum TonviewerURLContext {
    case history
    case nftItem
  }

  private let nft: NFT
  private let configurationStore: ConfigurationStore

  init(nft: NFT, configurationStore: ConfigurationStore) {
    self.nft = nft
    self.configurationStore = configurationStore
  }

  func buildLink(context: TonviewerURLContext, isTestnet: Bool) -> URL? {
    let configuration = configurationStore.getConfiguration()
    let stringAddress = nft.address.toFriendly().toString()

    let resultStringURL: String
    switch context {
    case .history:
      let accountExplorer = isTestnet ? configuration.accountExplorerTestnet : configuration.accountExplorer
      guard let url = accountExplorer else {
        return nil
      }
      resultStringURL = url.replacingOccurrences(of: "%s", with: stringAddress)
    case .nftItem:
      let nftOnExplorerUrl = isTestnet ? configuration.nftOnExplorerTestnetUrl : configuration.nftOnExplorerUrl
      guard let url = nftOnExplorerUrl else {
        return nil
      }
      resultStringURL = url.replacingOccurrences(of: "%s", with: stringAddress)
    }

    return URL(string: resultStringURL)
  }
}
