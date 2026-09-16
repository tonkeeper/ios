import SwiftUI
import TKUIKit
import UIKit

final class BatteryRefillHostingViewController: TKHostingController<BatteryRefillScreen> {
    private let viewModel: BatteryRefillViewModelImplementation

    init(
        viewModel: BatteryRefillViewModelImplementation,
        promocodeViewModel: BatteryPromocodeInputViewModel
    ) {
        self.viewModel = viewModel
        super.init(content: BatteryRefillScreen(
            viewModel: viewModel,
            promocodeViewModel: promocodeViewModel
        ))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        viewModel.showsCloseButton = presentingViewController != nil
        viewModel.didTapClose = { [weak self] in
            self?.dismiss(animated: true)
        }
        viewModel.endEditing = { [weak self] in
            self?.view.endEditing(true)
        }
        viewModel.viewDidLoad()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
}
