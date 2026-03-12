import TKUIKit
import UIKit

final class DappSharingPopupViewController: UIViewController, TKBottomSheetScrollContentViewController {
    private let viewModel: DappSharingPopupViewModel

    private let modalCardViewController = TKPopUp.ViewController()

    init(viewModel: DappSharingPopupViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - TKBottomSheetScrollContentViewController

    var scrollView: UIScrollView {
        modalCardViewController.scrollView
    }

    var didUpdateHeight: (() -> Void)?

    var headerItem: TKUIKit.TKPullCardHeaderItem?

    var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        modalCardViewController.calculateHeight(withWidth: width)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }

    private func setup() {
        addChild(modalCardViewController)
        view.addSubview(modalCardViewController.view)
        modalCardViewController.didMove(toParent: self)

        modalCardViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
    }

    func setupBindings() {
        viewModel.didUpdateConfiguration = { [weak self] configuration in
            self?.modalCardViewController.configuration = configuration
            self?.didUpdateHeight?()
        }
        viewModel.didTapShare = { [weak self] url in
            let activityViewController = UIActivityViewController(
                activityItems: [url as Any],
                applicationActivities: nil
            )
            self?.present(
                activityViewController,
                animated: true
            )
        }
    }
}
