import Foundation
import TonSwift

public protocol NFTService {
    func loadNFTs(addresses: [Address], network: Network) async throws -> [Address: NFT]
    func getNFT(address: Address, network: Network) throws -> NFT
    func saveNFT(nft: NFT, network: Network) throws
    func changeSuspiciousState(_ nft: NFT, network: Network, isScam: Bool) async throws
}

final class NFTServiceImplementation: NFTService {
    private let apiProvider: APIProvider
    private let scamAPI: ScamAPI
    private let nftRepository: NFTRepository

    init(
        apiProvider: APIProvider,
        scamAPI: ScamAPI,
        nftRepository: NFTRepository
    ) {
        self.apiProvider = apiProvider
        self.scamAPI = scamAPI
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

    func changeSuspiciousState(_ nft: NFT, network: Network, isScam: Bool) async throws {
        guard network == .mainnet else { return }
        try await scamAPI.changeSuspiciousState(nft, isScam: isScam, network: network)
    }
}
