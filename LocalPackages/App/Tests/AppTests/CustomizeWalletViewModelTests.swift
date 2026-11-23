@testable import App
import XCTest

@MainActor
final class CustomizeWalletViewModelTests: XCTestCase {
    func testResetContinueAllowsRetryingCustomization() {
        let viewModel = CustomizeWalletViewModel(name: "Wallet", configurator: TestCustomizeWalletConfigurator())

        viewModel.didTapContinue()

        XCTAssertFalse(viewModel.isContinueEnabled)
        XCTAssertTrue(viewModel.isContinueLoading)

        viewModel.resetContinue()

        XCTAssertTrue(viewModel.isContinueEnabled)
        XCTAssertFalse(viewModel.isContinueLoading)
    }
}

private final class TestCustomizeWalletConfigurator: CustomizeWalletViewModelConfigurator {
    var didCustomizeWallet: (() -> Void)?

    let continueButtonMode: CustomizeWalletViewModelContinueButtonMode = .visible(title: "Continue", action: {})
}
