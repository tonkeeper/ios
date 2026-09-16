import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct CollectiblesListMapper {
    let walletNftManagementStore: WalletNFTsManagementStore

    func map(nft: NFT, isSecureMode: Bool) -> CollectiblesListItem {
        let title: String = isSecureMode
            ? "* * * *"
            : (nft.name ?? nft.address.toString(bounceable: true))
        let isUnverified = !isSecureMode
            && nft.isUnverified
            && currentLocalState(nft) != .approved

        let subtitle: String = {
            if isSecureMode {
                return .secureModeValueShort
            }

            if isUnverified {
                return TKLocales.Purchases.unverified
            }

            guard let collection = nft.collection else {
                return TKLocales.Purchases.unnamedCollection
            }

            let name = collection.name
            if name == nil || name?.isEmpty == true {
                return TKLocales.Purchases.unnamedCollection
            }
            return name ?? TKLocales.Purchases.unnamedCollection
        }()

        return CollectiblesListItem(
            id: nft.address.toRaw(),
            title: title,
            subtitle: subtitle,
            subtitleColor: isUnverified ? .accentOrange : .textSecondary,
            imageSource: .url(nft.preview.size500),
            isSecureMode: isSecureMode,
            isOnSale: nft.sale != nil
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
