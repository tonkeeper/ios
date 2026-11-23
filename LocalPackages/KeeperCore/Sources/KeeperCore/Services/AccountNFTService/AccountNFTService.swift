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

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    func loadAccountNFTs(
        wallet: Wallet,
        collectionAddress: Address?,
        limit: Int?,
        offset: Int?,
        isIndirectOwnership: Bool
    ) async throws -> [NFT] {
        try await apiProvider.api(wallet.network).getAccountNftItems(
            address: wallet.address,
            collectionAddress: collectionAddress,
            limit: limit,
            offset: offset,
            isIndirectOwnership: isIndirectOwnership
        )
    }
}
