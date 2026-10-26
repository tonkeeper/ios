import Foundation
import KeeperCore

/// Reads and mutations happen on the main thread: the state feeds the NFT details screen and the
/// actions are invoked from its buttons.
final class NFTDetailsManageNFTModel {
    var didMarkAsSpam: (() -> Void)?

    var isVisible: Bool {
        wallet.isReportSpamAvailable
            && nft.isUnverified
            && nftManagementStore.state.nftStates[nftManagementItem] != .approved
    }

    private var markSpamNFTTask: Task<Void, Never>?
    private var approveNFTTask: Task<Void, Never>?

    private let wallet: Wallet
    private let nft: NFT
    private let nftManagementStore: WalletNFTsManagementStore

    init(
        wallet: Wallet,
        nft: NFT,
        nftManagementStore: WalletNFTsManagementStore
    ) {
        self.wallet = wallet
        self.nft = nft
        self.nftManagementStore = nftManagementStore
    }

    func approveNFT() {
        guard approveNFTTask == nil else { return }
        approveNFTTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await nftManagementStore.approveItem(nftManagementItem)
            approveNFTTask = nil
        }
    }

    func markSpamNFT() {
        guard markSpamNFTTask == nil else { return }
        markSpamNFTTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await nftManagementStore.spamItem(nftManagementItem)
            didMarkAsSpam?()
            markSpamNFTTask = nil
        }
    }

    private var nftManagementItem: NFTManagementItem {
        if let collection = nft.collection {
            .collection(collection.address)
        } else {
            .singleItem(nft.address)
        }
    }
}
