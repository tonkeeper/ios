import TKUIKit
import UIKit

/// List content for a token that has no history of its own. The header is the whole page, so it
/// gets a scroll view to keep the collapsing navigation bar and the insets the screen sets on it.
final class TokenDetailsHeaderContentViewController: UIViewController, TokenDetailsListContentViewController {
    var didPullToRefresh: (() -> Void)?

    let scrollView = UIScrollView()

    private var headerViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
    }

    func setHeaderViewController(_ headerViewController: UIViewController?) {
        self.headerViewController?.willMove(toParent: nil)
        self.headerViewController?.view.removeFromSuperview()
        self.headerViewController?.removeFromParent()
        self.headerViewController = headerViewController

        guard let headerViewController else { return }

        addChild(headerViewController)
        scrollView.addSubview(headerViewController.view)
        headerViewController.didMove(toParent: self)

        headerViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
    }
}
