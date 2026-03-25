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
}
