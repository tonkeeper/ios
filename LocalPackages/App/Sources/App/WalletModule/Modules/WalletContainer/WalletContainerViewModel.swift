import Foundation
import KeeperCore
import TKUIKit
import UIKit

protocol WalletContainerModuleOutput: AnyObject {
    var walletButtonHandler: (() -> Void)? { get set }
    var didTapSupportButton: (() -> Void)? { get set }
    var didTapSettingsButton: ((Wallet) -> Void)? { get set }
}

protocol WalletContainerViewModel: AnyObject {
    var didUpdateModel: ((WalletContainerView.Model) -> Void)? { get set }

    func viewDidLoad()
    func didTapWalletButton()
}

final class WalletContainerViewModelImplementation: WalletContainerViewModel, WalletContainerModuleOutput {
    typealias SettingsButtonModel = WalletContainerTopBarView.Model.SettingsButtonModel

    // MARK: - WalletContainerModuleOutput

    var walletButtonHandler: (() -> Void)?
    var didTapSupportButton: (() -> Void)?
    var didTapSettingsButton: ((Wallet) -> Void)?

    // MARK: - WalletContainerViewModel

    var didUpdateModel: ((WalletContainerView.Model) -> Void)?

    func viewDidLoad() {
        walletsStore.addObserver(self) { observer, event in
            DispatchQueue.main.async {
                switch event {
                case .didChangeActiveWallet,
                     .didUpdateWalletMetaData,
                     .didUpdateWalletSetupSettings,
                     .didUpdateWalletTron:
                    self.wallet = try? observer.walletsStore.activeWallet
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
    func createModel(wallet: Wallet) -> WalletContainerView.Model {
        let icon: WalletContainerWalletButton.Model.Icon
        switch wallet.icon {
        case let .emoji(emoji):
            icon = .emoji(emoji)
        case let .icon(image):
            icon = .image(image.image)
        }

        let walletButtonConfiguration = WalletContainerWalletButton.Model(
            title: wallet.label,
            icon: icon,
            color: wallet.tintColor.uiColor
        )

        var supportButtonConfiguration = TKButton.Configuration.accentButtonConfiguration(
            padding: UIEdgeInsets(
                top: 10,
                left: 10,
                bottom: 10,
                right: 10
            )
        )
        supportButtonConfiguration.content.icon = .TKUIKit.Icons.Size28.questionMessage
        supportButtonConfiguration.iconTintColor = .Icon.secondary
        supportButtonConfiguration.action = { [weak self] in
            self?.didTapSupportButton?()
        }

        var settingsButtonConfiguration = TKButton.Configuration.accentButtonConfiguration(
            padding: UIEdgeInsets(
                top: 10,
                left: 10,
                bottom: 10,
                right: 10
            )
        )
        settingsButtonConfiguration.content.icon = .TKUIKit.Icons.Size28.gearOutline
        settingsButtonConfiguration.iconTintColor = .Icon.secondary
        settingsButtonConfiguration.action = { [weak self] in
            self?.didTapSettingsButton?(wallet)
        }

        let isNotificationIndicatorVisible = wallet.isBackupAvailable && wallet.setupSettings.backupDate == nil
        let topBarViewModel = WalletContainerTopBarView.Model(
            walletButtonConfiguration: walletButtonConfiguration,
            supportButtonConfiguration: supportButtonConfiguration,
            settingButtonConfiguration: SettingsButtonModel(
                configuration: settingsButtonConfiguration,
                isIndicatorVisible: isNotificationIndicatorVisible
            )
        )
        return WalletContainerView.Model(
            topBarViewModel: topBarViewModel
        )
    }
}
