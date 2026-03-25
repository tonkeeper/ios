import TKCore
import TKUIKit
import UIKit

class RampMerchantPopUpViewController: GenericViewViewController<RampMerchantPopUpView>, TKBottomSheetScrollContentViewController {
    // MARK: - Module

    private let viewModel: RampMerchantPopUpViewModel

    // MARK: - Child

    private let popUpViewController = TKPopUp.ViewController()

    // MARK: - TKBottomSheetScrollContentViewController

    var scrollView: UIScrollView {
        popUpViewController.scrollView
    }

    var didUpdateHeight: (() -> Void)?

    var headerItem: TKUIKit.TKPullCardHeaderItem?

    var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        popUpViewController.calculateHeight(withWidth: width)
    }

    // MARK: - Init

    init(viewModel: RampMerchantPopUpViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }
}

// MARK: - Private

private extension RampMerchantPopUpViewController {
    func setup() {
        addChild(popUpViewController)
        customView.embedContent(popUpViewController.view)
        popUpViewController.didMove(toParent: self)
    }

    func setupBindings() {
        viewModel.didUpdateConfiguration = { [weak popUpViewController, weak self] configuration in
            popUpViewController?.configuration = configuration
            self?.didUpdateHeight?()
        }
    }
}
