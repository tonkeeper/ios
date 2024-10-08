import Foundation
import KeeperCore

struct TonviewerLinkBuilder {

  enum TonviewerURLContext {
    case history
    case nftItem
  }

  private let nft: NFT

  init(nft: NFT) {
    self.nft = nft
  }

  func buildLink(_ context: TonviewerURLContext) -> URL? {
    var urlComponents = URLComponents(string: "https://tonviewer.com/\(nft.address.toFriendly().toString())")
    var queryItems = [URLQueryItem]()
    switch context {
    case .history:
      break
    case .nftItem:
      queryItems.append(URLQueryItem(name: "section", value: "nft"))
    }
    urlComponents?.queryItems = queryItems
    return urlComponents?.url
  }
}
