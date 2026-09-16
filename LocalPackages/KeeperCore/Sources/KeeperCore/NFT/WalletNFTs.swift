import Foundation

public struct WalletNFTs: Codable, Equatable {
    public let all: [NFT]
    public let visible: [NFT]
    public let hidden: [NFT]
    public let spam: [NFT]
    public let blacklistedCount: Int

    public static var empty: WalletNFTs {
        WalletNFTs(
            all: [],
            visible: [],
            hidden: [],
            spam: [],
            blacklistedCount: 0
        )
    }

    public static func grouped(
        nfts: [NFT],
        managementState: NFTsManagementState
    ) -> WalletNFTs {
        var visible: [NFT] = []
        var hidden: [NFT] = []
        var spam: [NFT] = []
        var blacklistedCount = 0

        for nft in nfts {
            guard !nft.isHidden else { continue }
            let state: NFTsManagementState.NFTState?
            if let collection = nft.collection {
                state = managementState.nftStates[.collection(collection.address)]
            } else {
                state = managementState.nftStates[.singleItem(nft.address)]
            }

            switch nft.trust {
            case .blacklist:
                blacklistedCount += 1
            case .graylist, .none, .unknown, .whitelist:
                switch state {
                case .spam:
                    spam.append(nft)
                case .hidden:
                    hidden.append(nft)
                default:
                    visible.append(nft)
                }
            }
        }

        return WalletNFTs(
            all: nfts,
            visible: visible,
            hidden: hidden,
            spam: spam,
            blacklistedCount: blacklistedCount
        )
    }
}
