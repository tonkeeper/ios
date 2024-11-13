import UIKit
import KeeperCore
import TKCore
import TKLocalize

struct CollectiblesListMapper {

  let imageLoader = ImageLoader()
  let walletNftManagementStore: WalletNFTsManagementStore

  func map(nfts: [NFT], state: NFTsManagementState.NFTState?, isSecureMode: Bool) -> [CollectibleCollectionViewCell.Model] {
    nfts.map { nft in
      map(nft: nft, isSecureMode: isSecureMode)
    }
  }
  
  func map(nft: NFT, isSecureMode: Bool) -> CollectibleCollectionViewCell.Model {
    func composeSubtitle() -> String? {
      if isSecureMode {
        return .secureModeValueShort
      }

      if let collection = nft.collection {
        return (collection.name == nil || collection.name?.isEmpty == true) ? TKLocales.Purchases.unnamedCollection : collection.name
      } else {
        return TKLocales.Purchases.unnamedCollection
      }
    }

    let title: String = isSecureMode ? "* * * *" : nft.name ?? nft.address.toString(bounceable: true)
    
    let subtitle: NSAttributedString?
    if nft.isUnverified {
      let isManuallyApproved = currentLocalState(nft) == .approved
      let color: UIColor = isManuallyApproved ? .Text.secondary : .Accent.orange
      let composedSubtitle: String? = isManuallyApproved ? composeSubtitle() : TKLocales.Purchases.unverified
      subtitle = composedSubtitle?.withTextStyle(
        .body3,
        color: color,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    } else {
      subtitle = composeSubtitle()?.withTextStyle(
        .body3,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    }
    return CollectibleCollectionViewCell.Model(
      identifier: nft.address.toRaw(),
      imageDownloadTask: ImageDownloadTask(closure: { [weak imageLoader] imageView, size, cornerRadius in
        imageLoader?.loadImage(url: nft.preview.size500, imageView: imageView, size: size, cornerRadius: cornerRadius)
      }),
      title: title,
      subtitle: subtitle,
      isOnSale: nft.sale != nil,
      isBlurVisible: isSecureMode
    )
  }

  func currentLocalState(_ item: NFT) -> NFTsManagementState.NFTState? {
    let state: NFTsManagementState.NFTState?
    if let collection = item.collection {
      state = walletNftManagementStore.getState().nftStates[.collection(collection.address)]
    } else {
      state = walletNftManagementStore.getState().nftStates[.singleItem(item.address)]
    }
    return state
  }
}
