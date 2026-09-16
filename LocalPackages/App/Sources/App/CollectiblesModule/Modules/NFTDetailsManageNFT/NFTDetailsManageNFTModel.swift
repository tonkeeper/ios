import Foundation
import KeeperCore
import TKLogging

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
    private let nftService: NFTService

    init(
        wallet: Wallet,
        nft: NFT,
        nftManagementStore: WalletNFTsManagementStore,
        nftService: NFTService
    ) {
        self.wallet = wallet
        self.nft = nft
        self.nftManagementStore = nftManagementStore
        self.nftService = nftService
    }

    func approveNFT() {
        guard approveNFTTask == nil else { return }
        approveNFTTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await nftManagementStore.approveItem(nftManagementItem)
            await changeSuspiciousState(isScam: false)
            approveNFTTask = nil
        }
    }

    func markSpamNFT() {
        guard markSpamNFTTask == nil else { return }
        markSpamNFTTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await nftManagementStore.spamItem(nftManagementItem)
            didMarkAsSpam?()
            await changeSuspiciousState(isScam: true)
            markSpamNFTTask = nil
        }
    }

    private func changeSuspiciousState(isScam: Bool) async {
        do {
            try await nftService.changeSuspiciousState(
                nft,
                network: wallet.network,
                isScam: isScam
            )
        } catch {
            Log.w("NFTDetailsManageNFT: failed to change suspicious state to \(isScam), error: \(error)")
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
