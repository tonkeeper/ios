import Foundation
import TonSwift

public protocol AccountNFTService {
    func loadAccountNFTs(
        wallet: Wallet,
        collectionAddress: Address?,
        limit: Int?,
        offset: Int?,
        isIndirectOwnership: Bool
    ) async throws -> [NFT]
}

final class AccountNFTServiceImplementation: AccountNFTService {
    private let apiProvider: APIProvider
    private let accountNFTRepository: AccountNFTRepository
    private let nftRepository: NFTRepository

    init(apiProvider: APIProvider, accountNFTRepository: AccountNFTRepository, nftRepository: NFTRepository) {
        self.apiProvider = apiProvider
        self.accountNFTRepository = accountNFTRepository
        self.nftRepository = nftRepository
    }

    func loadAccountNFTs(
        wallet: Wallet,
        collectionAddress: Address?,
        limit: Int?,
        offset: Int?,
        isIndirectOwnership: Bool
    ) async throws -> [NFT] {
        let api = apiProvider.api(wallet.network)
        let nfts: [NFT]
        if limit == nil, offset == nil {
            nfts = try await api.getAllAccountNftItems(
                address: wallet.address,
                collectionAddress: collectionAddress,
                isIndirectOwnership: isIndirectOwnership
            )
        } else {
            nfts = try await api.getAccountNftItems(
                address: wallet.address,
                collectionAddress: collectionAddress,
                limit: limit,
                offset: offset,
                isIndirectOwnership: isIndirectOwnership
            )
        }
        try Task.checkCancellation()
        for nft in nfts {
            try? nftRepository.saveNFT(nft, key: nft.address.toRaw())
        }
        try? accountNFTRepository.saveNfts(nfts, key: wallet.friendlyAddress.toShort())
        return nfts
    }
}
