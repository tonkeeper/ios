import Foundation
import TonSwift

public struct AccountNfts {
    let wallet: Wallet
    let nfts: [NFT]
}

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
        do {
            let nfts = try await apiProvider.api(wallet.network).getAccountNftItems(
                address: wallet.address,
                collectionAddress: collectionAddress,
                limit: limit,
                offset: offset,
                isIndirectOwnership: isIndirectOwnership
            )
            for nft in nfts {
                try? nftRepository.saveNFT(nft, key: nft.address.toRaw())
            }
            try? accountNFTRepository.saveNfts(nfts, key: wallet.friendlyAddress.toShort())
            return nfts
        } catch {
            try? accountNFTRepository.saveNfts([], key: wallet.friendlyAddress.toShort())
            throw error
        }
    }
}
