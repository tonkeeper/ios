import SwiftUI
import TKUIKit
import UIKit

final class BatteryRechargeHostingViewController: TKHostingController<BatteryRechargeScreen> {
    private let viewModel: BatteryRechargeViewModelImplementation

    init(
        viewModel: BatteryRechargeViewModelImplementation,
        amountInputViewModel: AmountInputSwiftUIViewModel,
        promocodeViewModel: BatteryPromocodeInputViewModel,
        recipientViewModel: RecipientInputViewModel
    ) {
        self.viewModel = viewModel
        super.init(content: BatteryRechargeScreen(
            viewModel: viewModel,
            amountInputViewModel: amountInputViewModel,
            promocodeViewModel: promocodeViewModel,
            recipientViewModel: recipientViewModel
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
