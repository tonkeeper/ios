import AppUI
import Combine
import TKUIKit
import UIKit

/// Hosts the shared amount card on a UIKit screen. Its height follows the balance row, since a
/// hosting view reports no height to Auto Layout on iOS 15.
final class AmountInputViewController: UIViewController {
    private let viewModel: AmountInputSwiftUIViewModel
    private let hostingController: TKHostingController<AmountInputSwiftUIView>
    private var heightConstraint: NSLayoutConstraint?
    private var cancellable: AnyCancellable?

    init(viewModel: AmountInputSwiftUIViewModel, textFieldAccessibilityIdentifier: String? = nil) {
        self.viewModel = viewModel
        hostingController = TKHostingController(content: AmountInputSwiftUIView(
            viewModel: viewModel,
            textFieldAccessibilityIdentifier: textFieldAccessibilityIdentifier
        ))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        viewModel.requestFocus()
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        hostingController.didMove(toParent: self)

        let heightConstraint = view.heightAnchor.constraint(
            equalToConstant: AmountInputSheet.height(
                showsBalance: viewModel.showsBalance,
                showsQuickOptions: viewModel.showsQuickOptions
            )
        )
        heightConstraint.isActive = true
        self.heightConstraint = heightConstraint
        cancellable = Publishers.CombineLatest(viewModel.$showsBalance, viewModel.$showsQuickOptions)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] showsBalance, showsQuickOptions in
                self?.heightConstraint?.constant = AmountInputSheet.height(
                    showsBalance: showsBalance,
                    showsQuickOptions: showsQuickOptions
                )
            }
    }
}
