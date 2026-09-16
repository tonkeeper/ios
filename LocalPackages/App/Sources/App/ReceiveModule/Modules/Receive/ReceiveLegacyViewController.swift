import TKUIKit
import UIKit

final class ReceiveLegacyViewController: GenericViewViewController<ReceiveView> {
    private var tabViewController: UIViewController?

    private let viewModel: ReceiveLegacyViewModel

    init(viewModel: ReceiveLegacyViewModel) {
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
        setupViewEvents()
        setupBindings()
        viewModel.viewDidLoad()
    }
}

private extension ReceiveLegacyViewController {
    func setup() {
        setupNavigationBar()
    }

    func setupBindings() {
        viewModel.didUpdateTokenViewController = { [weak self] viewController, _ in
            self?.setTabViewController(viewController)
        }
        viewModel.didUpdateSegmentedControl = { [weak self] model in
            guard let self else { return }
            if let model {
                customView.navigationBar.centerView = customView.segmentedControl
                customView.segmentedControl.tabs = model
            } else {
                customView.navigationBar.centerView = nil
            }
        }
        viewModel.didChangeIndex = { [weak self] index in
            self?.customView.segmentedControl.setSelectedIndex(index, animated: false)
        }
    }

    func setupViewEvents() {
        customView.segmentedControl.didSelectTab = { [weak self] from, to in
            self?.viewModel.setActiveIndex(from, to)
        }
    }

    func setupNavigationBar() {
        customView.navigationBar.leftViews = [
            TKUINavigationBar.createSwipeDownButton { [weak self] in
                self?.viewModel.close()
            },
        ]
        customView.navigationBar.centerView = customView.segmentedControl
    }

    func setTabViewController(_ tabViewController: ReceiveTabViewController) {
        addChild(tabViewController)
        customView.pageContainer.addSubview(tabViewController.view)
        tabViewController.didMove(toParent: self)

        customView.navigationBar.scrollView = tabViewController.customView.scrollView

        tabViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(customView.pageContainer)
        }

        self.tabViewController?.willMove(toParent: nil)
        self.tabViewController?.view.removeFromSuperview()
        self.tabViewController?.didMove(toParent: nil)
        self.tabViewController = tabViewController
    }
}
