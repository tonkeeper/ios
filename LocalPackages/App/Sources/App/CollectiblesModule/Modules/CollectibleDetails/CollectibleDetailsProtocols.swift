import Foundation
import TonSwift
import KeeperCore

protocol CollectibleDetailsModuleOutput: AnyObject {
  func collectibleDetailsDidFinish(_ collectibleDetails: CollectibleDetailsModuleInput)
  func collectibleDetails(
    _ collectibleDetails: CollectibleDetailsModuleInput,
    transferNFT nft: NFT
  )
  func collectibleDetailsLinkDomain(_ collectibleDetails: CollectibleDetailsModuleInput, nft: NFT)
  func collectibleDetailsUnlinkDomain(_ collectibleDetails: CollectibleDetailsModuleInput, nft: NFT)
  func collectibleDetailsRenewDomain(_ collectibleDetails: CollectibleDetailsModuleInput, nft: NFT)
}

protocol CollectibleDetailsModuleInput: AnyObject {}

protocol CollectibleDetailsPresenterInput {
  func viewDidLoad()
  func didTapSwipeButton()
  func didTapOpenInExplorerButton()
}

protocol CollectibleDetailsViewInput: AnyObject {
  func updateTitle(_ title: String?)
  func updateView(model: CollectibleDetailsView.Model)
}
