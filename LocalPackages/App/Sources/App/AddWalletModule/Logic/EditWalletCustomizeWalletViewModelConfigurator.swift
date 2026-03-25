import Foundation
import KeeperCore

final class EditWalletCustomizeWalletViewModelConfigurator: CustomizeWalletViewModelConfigurator {
    var didCustomizeWallet: (() -> Void)?

    var continueButtonMode: CustomizeWalletViewModelContinueButtonMode {
        .hidden
    }

    func didSelectColor() {
        didCustomizeWallet?()
    }

    func didEditName() {
        didCustomizeWallet?()
    }
}
