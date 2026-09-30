import TKLocalize
import TKUIKit
import UIKit

final class TradeAssetHistoryViewController: UIViewController {
    private let navigationBar = TKUINavigationBar()
    private let listViewController: HistoryListViewController
    private let onBack: () -> Void
    private var wasNavigationBarHidden: Bool?

    init(
        listViewController: HistoryListViewController,
        onBack: @escaping () -> Void
    ) {
        self.listViewController = listViewController
        self.onBack = onBack
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Background.page

        let titleView = TKUINavigationBarTitleView()
        titleView.configure(
            model: TKUINavigationBarTitleView.Model(title: TKLocales.Trade.AssetDetails.History.title)
        )
        navigationBar.centerView = titleView

        let backButton = TKUINavigationBar.createBackButton { [onBack] in
            onBack()
        }
        backButton.accessibilityIdentifier = "history_back_button"
        navigationBar.leftViews = [backButton]

        addChild(listViewController)
        view.addSubview(listViewController.view)
        view.addSubview(navigationBar)
        listViewController.didMove(toParent: self)

        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(view)
        }
        listViewController.view.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.right.bottom.equalTo(view)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if wasNavigationBarHidden == nil {
            wasNavigationBarHidden = navigationController?.isNavigationBarHidden
        }
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let wasNavigationBarHidden else { return }
        navigationController?.setNavigationBarHidden(wasNavigationBarHidden, animated: animated)
    }
}
