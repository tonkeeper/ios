import Foundation
import TonSwift

public final class WalletNFTsManagementStore: Store<WalletNFTsManagementStore.Event, NFTsManagementState> {
    public enum Event {
        case didUpdateState(wallet: Wallet)
    }

    private let wallet: Wallet
    private let accountNFTsManagementRepository: AccountNFTsManagementRepository

    init(
        wallet: Wallet,
        accountNFTsManagementRepository: AccountNFTsManagementRepository
    ) {
        self.wallet = wallet
        self.accountNFTsManagementRepository = accountNFTsManagementRepository
        super.init(state: NFTsManagementState(nftStates: [:]))
    }

    override public func createInitialState() -> NFTsManagementState {
        accountNFTsManagementRepository.getState(wallet: wallet)
    }

    // MARK: -  async

    public func hideItem(_ item: NFTManagementItem) async {
        await withCheckedContinuation { continuation in
            hideItem(item) {
                continuation.resume()
            }
        }
    }

    public func approveItem(_ item: NFTManagementItem) async {
        await withCheckedContinuation { continuation in
            approveItem(item) {
                continuation.resume()
            }
        }
    }

    public func spamItem(_ item: NFTManagementItem) async {
        await withCheckedContinuation { continuation in
            spamItem(item) {
                continuation.resume()
            }
        }
    }

    public func hideItem(
        _ item: NFTManagementItem,
        completion: (() -> Void)? = nil
    ) {
        changeItemState(
            newState: .hidden,
            item: item,
            completion: completion
        )
    }

    public func showItem(
        _ item: NFTManagementItem,
        completion: (() -> Void)? = nil
    ) {
        changeItemState(
            newState: .visible,
            item: item,
            completion: completion
        )
    }

    public func approveItem(
        _ item: NFTManagementItem,
        completion: (() -> Void)? = nil
    ) {
        changeItemState(
            newState: .approved,
            item: item,
            completion: completion
        )
    }

    public func spamItem(
        _ item: NFTManagementItem,
        completion: (() -> Void)? = nil
    ) {
        changeItemState(
            newState: .spam,
            item: item,
            completion: completion
        )
    }

    private func changeItemState(
        newState: NFTsManagementState.NFTState,
        item: NFTManagementItem,
        completion: (() -> Void)? = nil
    ) {
        updateState { [accountNFTsManagementRepository, wallet] state in
            var updatedNFTStates = state.nftStates
            updatedNFTStates[item] = newState
            let updatedState = NFTsManagementState(nftStates: updatedNFTStates)
            try? accountNFTsManagementRepository.setState(updatedState, wallet: wallet)
            return WalletNFTsManagementStore.StateUpdate(newState: updatedState)
        } completion: { [weak self, wallet] _ in
            self?.sendEvent(.didUpdateState(wallet: wallet))
            completion?()
        }
    }
}
