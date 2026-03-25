import SnapKit
import UIKit

public final class TKTabBarController: UITabBarController {
    public var didLongPressTabBarItem: ((Int) -> Void)?

    public let blurView = TKBlurView()

    private lazy var longPressRecognizer = UILongPressGestureRecognizer(
        target: self,
        action: #selector(longPressHandler(_:))
    )

    public init() {
        super.init(nibName: nil, bundle: nil)
        object_setClass(self.tabBar, TKTabBar.self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        if !UIApplication.useSystemBarsAppearance {
            view.insertSubview(blurView, belowSubview: tabBar)

            blurView.snp.makeConstraints { make in
                make.edges.equalTo(tabBar)
            }
        } else {
            longPressRecognizer.delegate = self
        }

        tabBar.addGestureRecognizer(longPressRecognizer)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    @objc
    func longPressHandler(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let tabBarItems = tabBar.items else { return }
        let location = recognizer.location(in: tabBar)
        for (index, item) in tabBarItems.enumerated() {
            guard let view = item.value(forKey: "view") as? UIView else { continue }
            guard view.frame.contains(location) else { continue }

            didLongPressTabBarItem?(index)
        }
    }
}

extension TKTabBarController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return [gestureRecognizer, otherGestureRecognizer].contains(longPressRecognizer)
    }
}

public extension UIApplication {
    static var useSystemBarsAppearance: Bool {
        guard #available(iOS 26.0, *) else { return false }

        return Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true
    }
}
