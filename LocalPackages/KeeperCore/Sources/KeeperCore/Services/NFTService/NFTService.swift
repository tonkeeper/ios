import Foundation
import TonSwift

public protocol NFTService {
    func loadNFTs(addresses: [Address], network: Network) async throws -> [Address: NFT]
    func getNFT(address: Address, network: Network) throws -> NFT
    func saveNFT(nft: NFT, network: Network) throws
}

final class NFTServiceImplementation: NFTService {
    private let apiProvider: APIProvider
    private let nftRepository: NFTRepository

    init(
        apiProvider: APIProvider,
        nftRepository: NFTRepository
    ) {
        self.apiProvider = apiProvider
        self.nftRepository = nftRepository
    }

    func loadNFTs(addresses: [Address], network: Network) async throws -> [Address: NFT] {
        let isTestnet = network == .testnet
        let nfts = try await apiProvider.api(network).getNftItemsByAddresses(addresses)
        var result = [Address: NFT]()
        for nft in nfts {
            try? nftRepository.saveNFT(
                nft,
                key: FriendlyAddress(address: nft.address, testOnly: isTestnet, bounceable: true).toShort()
            )
            result[nft.address] = nft
        }
        return result
    }

    func getNFT(address: Address, network: Network) throws -> NFT {
        try nftRepository.getNFT(
            FriendlyAddress(address: address, testOnly: network == .testnet, bounceable: true).toShort()
        )
    }

    func saveNFT(nft: NFT, network: Network) throws {
        try nftRepository.saveNFT(
            nft,
            key: FriendlyAddress(address: nft.address, testOnly: network == .testnet, bounceable: true).toShort()
        )
    }
}
