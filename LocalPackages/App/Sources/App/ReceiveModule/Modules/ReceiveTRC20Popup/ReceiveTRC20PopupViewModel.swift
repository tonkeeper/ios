import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import TronSwift
import UIKit

@MainActor
public protocol ReceiveTRC20PopupModuleOutput: AnyObject {
    var didFinish: (() -> Void)? { get set }
    var didEnable: (() -> Void)? { get set }
}

@MainActor
protocol ReceiveTRC20PopupViewModel: AnyObject {
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }

    func viewDidLoad()
}

@MainActor
final class ReceiveTRC20PopupViewModelImplementation: ReceiveTRC20PopupViewModel, ReceiveTRC20PopupModuleOutput {
    // MARK: - State

    private var enableTRC20Task: Task<Void, Swift.Error>?

    // MARK: - Dependencies

    private let wallet: Wallet
    private let tronWalletConfigurator: TronWalletConfigurator
    private var passcodeProvider: () async -> String?

    init(
        wallet: Wallet,
        tronWalletConfigurator: TronWalletConfigurator,
        passcodeProvider: @escaping () async -> String?
    ) {
        self.wallet = wallet
        self.tronWalletConfigurator = tronWalletConfigurator
        self.passcodeProvider = passcodeProvider
    }

    // MARK: - ReceiveTRC20PopupViewModel

    var didFinish: (() -> Void)?
    var didEnable: (() -> Void)?

    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?

    func viewDidLoad() {
        prepareContent()
    }

    private func prepareContent() {
        var enableButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        enableButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Receive.Trc20.Popup.Buttons.enable))
        enableButtonConfiguration.action = { [weak self] in
            guard self?.enableTRC20Task == nil else { return }
            self?.enableTRC20Task = Task { [weak self] in
                guard let self else { return }
                try await tronWalletConfigurator.turnOn(wallet: wallet, passcodeProvider: passcodeProvider)
                self.didEnable?()
                self.didFinish?()
            }
        }

        var laterButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        laterButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Receive.Trc20.Popup.Buttons.later))
        laterButtonConfiguration.action = { [weak self] in
            self?.didFinish?()
        }

        let configuration = TKPopUp.Configuration(
            items: [
                TransactionConfirmationHeaderImageItem(
                    configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                        image: .image(.App.Currency.Size96.usdt),
                        corners: .circle,
                        badge: TransactionConfirmationHeaderImageItemView.Configuration.Badge(
                            image: .image(.App.Currency.Vector.trc20)
                        )
                    ),
                    bottomSpace: 20
                ),
                TKPopUp.Component.TitleCaption(
                    title: TKLocales.Receive.Trc20.Popup.title,
                    caption: TKLocales.Receive.Trc20.Popup.caption,
                    bottomSpace: 0
                ),
                TKPopUp.Component.ButtonGroupComponent(
                    buttons: [
                        TKPopUp.Component.ButtonComponent(
                            buttonConfiguration: enableButtonConfiguration
                        ),
                        TKPopUp.Component.ButtonComponent(
                            buttonConfiguration: laterButtonConfiguration
                        ),
                    ]
                ),
            ]
        )

        didUpdateConfiguration?(configuration)
    }
}
