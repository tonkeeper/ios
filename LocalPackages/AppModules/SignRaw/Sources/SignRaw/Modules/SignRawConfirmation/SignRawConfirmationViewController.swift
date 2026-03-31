import TKUIKit
import UIKit

public final class SignRawConfirmationViewController: GenericViewViewController<SignRawConfirmationView>, TKBottomSheetScrollContentViewController {
    private let viewModel: SignRawConfirmationViewModel

    private let popUpViewController = TKPopUp.ViewController()

    // MARK: - TKBottomSheetScrollContentViewController

    public var scrollView: UIScrollView {
        popUpViewController.scrollView
    }

    public var didUpdateHeight: (() -> Void)?

    public var headerItem: TKUIKit.TKPullCardHeaderItem?

    public var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?

    public func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        popUpViewController.calculateHeight(withWidth: width)
    }

    init(viewModel: SignRawConfirmationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }

    private func setup() {
        setupContent()
    }

    private func setupBindings() {
        viewModel.didUpdateHeader = { [weak self] in
            self?.didUpdatePullCardHeaderItem?($0)
        }
        viewModel.didUpdateConfiguration = { [weak self] in
            self?.popUpViewController.configuration = $0
            self?.didUpdateHeight?()
        }
    }

    func setupContent() {
        addChild(popUpViewController)
        customView.embedContent(popUpViewController.view)
        popUpViewController.didMove(toParent: self)
    }
}
