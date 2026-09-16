import KeeperCore
import UIKit

protocol WalletTabCoordinatorOutput: AnyObject {
    var didTapScan: (() -> Void)? { get set }
    var didTapWalletButton: (() -> Void)? { get set }
    var didTapSend: ((Wallet) -> Void)? { get set }
    var didTapWithdraw: ((Wallet) -> Void)? { get set }
    var didTapDeposit: ((Wallet) -> Void)? { get set }
    var didTapSwap: ((Wallet) -> Void)? { get set }
    var didTapStake: ((Wallet) -> Void)? { get set }
    var didTapSettingsButton: ((Wallet) -> Void)? { get set }
    var didTapHistoryButton: (() -> Void)? { get set }
    var didSelectTonDetails: ((Wallet) -> Void)? { get set }
    var didSelectJettonDetails: ((Wallet, JettonItem, Bool) -> Void)? { get set }
    var didSelectTronUSDTDetails: ((Wallet) -> Void)? { get set }
    var didSelectTronTRXDetails: ((Wallet) -> Void)? { get set }
    var didSelectEthenaDetails: ((Wallet) -> Void)? { get set }
    var didSelectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)? { get set }
    var didSelectCollectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)? { get set }
    var didTapBackup: ((Wallet) -> Void)? { get set }
    var didTapBattery: ((Wallet) -> Void)? { get set }
    var didTapOpenCryptoAssets: (() -> Void)? { get set }

    func historyButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void)
    func walletButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void)
}

extension WalletCoordinator: WalletTabCoordinatorOutput {}
