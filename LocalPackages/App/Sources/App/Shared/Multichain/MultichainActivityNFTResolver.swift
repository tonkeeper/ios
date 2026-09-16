import Foundation
import KeeperCore
import TKLocalize
import TKLogging
import TonSwift

struct MultichainActivityNFT: Equatable {
    static let amountTitle = "NFT"

    let id: String
    let name: String
    let collectionName: String
    let imageURL: URL?
    let isVerified: Bool
}

@MainActor
final class MultichainActivityNFTResolver: ObservableObject {
    @Published private(set) var revision = 0

    private let nftService: NFTService
    private let network: Network

    private var nftsByAddress = [String: MultichainActivityNFT]()
    private var requestedAddresses = Set<String>()

    init(nftService: NFTService, network: Network) {
        self.nftService = nftService
        self.network = network
    }

    func nft(for activity: MultichainActivity) -> MultichainActivityNFT? {
        guard let address = Self.nftAddress(for: activity) else {
            return nil
        }
        return nftsByAddress[address]
    }

    func resolve(activities: [MultichainActivity]) async {
        var parsedAddresses = [String: Address]()
        for activity in activities {
            guard let rawAddress = Self.nftAddress(for: activity),
                  !requestedAddresses.contains(rawAddress),
                  let address = Self.parseTonAddress(rawAddress)
            else {
                continue
            }
            parsedAddresses[rawAddress] = address
        }

        guard !parsedAddresses.isEmpty else {
            return
        }

        let nfts: [Address: NFT]
        do {
            nfts = try await nftService.loadNFTs(
                addresses: Array(Set(parsedAddresses.values)),
                network: network
            )
        } catch {
            Log.w("multichain history: failed to load NFTs for \(parsedAddresses.count) addresses: \(error)")
            return
        }

        requestedAddresses.formUnion(parsedAddresses.keys)

        var didResolve = false
        for (rawAddress, address) in parsedAddresses {
            guard let nft = nfts[address],
                  let activityNFT = MultichainActivityNFT(nft: nft)
            else {
                continue
            }
            nftsByAddress[rawAddress] = activityNFT
            didResolve = true
        }

        if didResolve {
            revision += 1
        }
    }
}

private extension MultichainActivityNFTResolver {
    static func nftAddress(for activity: MultichainActivity) -> String? {
        guard !activity.isSpam else {
            return nil
        }

        if activity.activityType == .dnsRenew {
            return activity.toChain == .ton ? activity.toAddress : nil
        }

        let assetId: String?
        switch activity.direction {
        case .incoming:
            assetId = activity.inToken?.assetId
        case .outgoing, .selfTransfer:
            assetId = activity.outToken?.assetId
        }

        guard let assetId,
              case let .asset(chain, _, type, address) = AssetIdComponents(assetId: assetId),
              MultichainChain(assetIdChain: chain) == .ton,
              type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix(nftAssetTypePrefix)
        else {
            return nil
        }
        return address
    }

    static func parseTonAddress(_ rawAddress: String) -> Address? {
        do {
            return try Address.parse(rawAddress)
        } catch {
            Log.w("multichain history: failed to parse NFT address \(rawAddress): \(error)")
            return nil
        }
    }

    static let nftAssetTypePrefix = "nft"
}

private extension MultichainActivityNFT {
    init?(nft: NFT) {
        let collectionName: String
        switch nft.trust {
        case .whitelist, .graylist:
            collectionName = nft.collection?.notEmptyName ?? TKLocales.NftDetails.singleNft
        case .none, .unknown:
            collectionName = TKLocales.NftDetails.unverifiedNft
        case .blacklist:
            return nil
        }

        self.init(
            id: nft.address.toRaw(),
            name: nft.notNilName,
            collectionName: collectionName,
            imageURL: nft.preview.size500 ?? nft.imageURL,
            isVerified: nft.trust == .whitelist
        )
    }
}
