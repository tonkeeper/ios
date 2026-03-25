import TKUIKit
import UIKit

final class SignDataViewController: GenericViewViewController<SignDataView>, TKBottomSheetScrollContentViewController {
    var scrollView: UIScrollView {
        popUpViewController.scrollView
    }

    var didUpdateHeight: (() -> Void)?

    var headerItem: TKUIKit.TKPullCardHeaderItem?

    var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?

    var didSign: ((String?) -> Void)?

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        popUpViewController.calculateHeight(withWidth: width)
    }

    private let viewModel: SignDataViewModel

    private let popUpViewController = TKPopUp.ViewController()

    init(viewModel: SignDataViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }
}

private extension SignDataViewController {
    func setupBindings() {
        viewModel.didUpdateHeader = { [weak self] in
            self?.didUpdatePullCardHeaderItem?($0)
        }

        viewModel.didUpdateConfiguration = { [weak self] configuration in
            self?.popUpViewController.configuration = configuration
            self?.didUpdateHeight?()
        }

        viewModel.didTapCopy = { text in
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            UIPasteboard.general.string = text
        }

        viewModel.showToast = { configuration in
            ToastPresenter.showToast(configuration: configuration)
        }
    }

    func setup() {
        setupModalContent()
    }

    func setupModalContent() {
        addChild(popUpViewController)
        customView.embedContent(popUpViewController.view)
        popUpViewController.didMove(toParent: self)
    }
}
