import UIKit

public final class TKNavigationController: UINavigationController {
    private let gradientView = TKGradientView(color: .Background.page, direction: .topToBottom)

    override public var preferredStatusBarStyle: UIStatusBarStyle {
        TKThemeManager.shared.theme.themeAppaearance.statusBarStyle(for: traitCollection.userInterfaceStyle)
    }

    override public init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        setup()
    }

    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setup()
    }

    public init() {
        super.init(nibName: nil, bundle: nil)
        setup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// For a stack whose screens choose their own orientations, as a dapp does; otherwise the app default.
    public var forwardsSupportedInterfaceOrientations = false

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard forwardsSupportedInterfaceOrientations, let topViewController else { return .tkDefault }
        return topViewController.supportedInterfaceOrientations
    }

    override public var shouldAutorotate: Bool {
        guard forwardsSupportedInterfaceOrientations, let topViewController else { return super.shouldAutorotate }
        return topViewController.shouldAutorotate
    }

    public var didDismiss: (() -> Void)?

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            didDismiss?()
        }
    }
}

private extension TKNavigationController {
    func setup() {
        view.insertSubview(gradientView, belowSubview: navigationBar)
        gradientView.snp.makeConstraints { make in
            make.top.left.right.equalTo(view)
            make.bottom.equalTo(navigationBar)
        }
    }
}
