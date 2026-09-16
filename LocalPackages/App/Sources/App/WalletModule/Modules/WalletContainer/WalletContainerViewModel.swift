import Foundation
import KeeperCore
import TKUIKit
import UIKit

protocol WalletContainerModuleOutput: AnyObject {
    var walletButtonHandler: (() -> Void)? { get set }
    var didTapScan: (() -> Void)? { get set }
    var didTapSettingsButton: ((Wallet) -> Void)? { get set }
    var didTapHistoryButton: (() -> Void)? { get set }
}

protocol WalletContainerViewModel: AnyObject {
    var didUpdateModel: ((WalletContainerTopBarModel) -> Void)? { get set }

    func viewDidLoad()
    func didTapWalletButton()
}

final class WalletContainerViewModelImplementation: WalletContainerViewModel, WalletContainerModuleOutput {
    // MARK: - WalletContainerModuleOutput

    var walletButtonHandler: (() -> Void)?
    var didTapScan: (() -> Void)?
    var didTapSettingsButton: ((Wallet) -> Void)?
    var didTapHistoryButton: (() -> Void)?

    // MARK: - WalletContainerViewModel

    var didUpdateModel: ((WalletContainerTopBarModel) -> Void)?

    func viewDidLoad() {
        walletsStore.addObserver(self) { observer, event in
            DispatchQueue.main.async {
                switch event {
                case .didChangeActiveWallet,
                     .didUpdateWalletMetaData,
                     .didUpdateWalletMultichain,
                     .didUpdateWalletSetupSettings:
                    observer.wallet = try? observer.walletsStore.activeWallet
                default: break
                }
            }
        }
        setInitialState()
    }

    // MARK: - State

    private var wallet: Wallet? {
        didSet {
            guard let wallet else { return }
            didUpdateModel?(createModel(wallet: wallet))
        }
    }

    func didTapWalletButton() {
        walletButtonHandler?()
    }

    // MARK: - Dependencies

    private let walletsStore: WalletsStore

    // MARK: - Init

    init(walletsStore: WalletsStore) {
        self.walletsStore = walletsStore
    }

    private func setInitialState() {
        guard let wallet = try? walletsStore.activeWallet else { return }
        self.wallet = wallet
    }
}

private extension WalletContainerViewModelImplementation {
    func createModel(wallet: Wallet) -> WalletContainerTopBarModel {
        let icon: WalletButtonConfig.Icon
        switch wallet.icon {
        case let .emoji(emoji):
            icon = .emoji(emoji)
        case let .icon(image):
            icon = .image(image.image)
        }

        return WalletContainerTopBarModel(
            walletButton: WalletButtonConfig(
                title: wallet.label,
                icon: icon,
                color: wallet.tintColor.themedColor
            ),
            walletButtonAction: { [weak self] in
                self?.didTapWalletButton()
            },
            scanButton: WalletContainerTopBarModel.IconButton(
                icon: .TKUIKit.Icons.Size28.qrViewFinderThin,
                action: { [weak self] in
                    self?.didTapScan?()
                }
            ),
            historyButton: WalletContainerTopBarModel.IconButton(
                icon: .TKUIKit.Icons.Size28.clockOutline,
                action: { [weak self] in
                    self?.didTapHistoryButton?()
                }
            ),
            settingsButton: WalletContainerTopBarModel.IconButton(
                icon: .TKUIKit.Icons.Size28.gearOutline,
                action: { [weak self] in
                    self?.didTapSettingsButton?(wallet)
                }
            ),
            isSettingsIndicatorVisible: wallet.isBackupAvailable && wallet.setupSettings.backupDate == nil
        )
    }
}
