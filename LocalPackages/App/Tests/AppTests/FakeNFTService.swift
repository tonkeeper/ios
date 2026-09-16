@testable import App
import Foundation
@testable import KeeperCore
import TonSwift

/// Test double for the KeeperCore NFT seam so App view models can resolve NFT
/// metadata without tonapi.
final class FakeNFTService: NFTService, @unchecked Sendable {
    enum Failure: Error {
        case notFound
    }

    var nftsByAddress = [Address: NFT]()
    var loadError: Error?
    private(set) var loadedAddresses = [[Address]]()

    func loadNFTs(addresses: [Address], network _: Network) async throws -> [Address: NFT] {
        loadedAddresses.append(addresses)
        if let loadError {
            throw loadError
        }
        return nftsByAddress.filter { addresses.contains($0.key) }
    }

    func getNFT(address: Address, network _: Network) throws -> NFT {
        guard let nft = nftsByAddress[address] else {
            throw Failure.notFound
        }
        return nft
    }

    func saveNFT(nft: NFT, network _: Network) throws {
        nftsByAddress[nft.address] = nft
    }

    func changeSuspiciousState(_: NFT, network _: Network, isScam _: Bool) async throws {}
}

extension FakeNFTService {
    static func makeNFT(
        address: Address,
        name: String? = "Chest #355937",
        collectionName: String? = "CheQUEs Chests: The Purge",
        trust: NFT.Trust = .whitelist,
        previewURL: URL? = URL(string: "https://cache.tonapi.io/nft/preview500.png")
    ) -> NFT {
        NFT(
            address: address,
            owner: nil,
            name: name,
            imageURL: URL(string: "https://cache.tonapi.io/nft/original.png"),
            preview: NFT.Preview(
                size5: nil,
                size100: nil,
                size500: previewURL,
                size1500: nil
            ),
            description: nil,
            attributes: [],
            collection: collectionName.map {
                NFTCollection(
                    address: address,
                    name: $0,
                    description: nil
                )
            },
            programmaticButtons: nil,
            dns: nil,
            sale: nil,
            trust: trust,
            renderType: nil,
            lottieURL: nil
        )
    }
}
