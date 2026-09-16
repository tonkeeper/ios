import Foundation
import KeeperCore
import TKCore
import TKUIKit
import UIKit

struct CustomizeWalletAssembly {
    private init() {}
    static func module(
        name: String?,
        tintColor: WalletTintColor?,
        icon: WalletIcon?,
        configurator: CustomizeWalletViewModelConfigurator
    ) -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void> {
        let viewModel = CustomizeWalletViewModel(
            name: name,
            tintColor: tintColor,
            icon: icon,
            configurator: configurator
        )
        let viewController = CustomizeWalletHostingViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}

final class CustomizeWalletHostingViewController: TKHostingController<CustomizeWalletScreen>, TKOwnHeaderScreen {
    private let viewModel: CustomizeWalletViewModel

    init(viewModel: CustomizeWalletViewModel) {
        self.viewModel = viewModel
        super.init(content: CustomizeWalletScreen(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBar(animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreNavigationBar(animated: animated)
    }

    func setupHeaderBackButton() {
        viewModel.leftHeaderButton = CustomizeWalletViewModel.HeaderButton(icon: .back) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    func setupHeaderLeftCloseButton(_ action: @escaping () -> Void) {
        viewModel.leftHeaderButton = CustomizeWalletViewModel.HeaderButton(icon: .close, action: action)
    }

    func setupHeaderRightCloseButton(_ action: @escaping () -> Void) {
        viewModel.rightHeaderButton = CustomizeWalletViewModel.HeaderButton(icon: .close, action: action)
    }
}
