import UIKit

public struct TKPullCardHeaderItem {
    public struct LeftButton {
        enum Model {
            case icon(TKUIHeaderIconButton.Model)
            case titleIcon(TKUIHeaderTitleIconButton.Model)
        }

        let model: Model
        let action: (_ button: UIControl) -> Void
        let isEnabled: Bool

        public init(
            model: TKUIHeaderTitleIconButton.Model,
            action: @escaping ((_ button: UIControl) -> Void),
            isEnabled: Bool = true
        ) {
            self.model = .titleIcon(model)
            self.action = action
            self.isEnabled = isEnabled
        }

        public init(
            model: TKUIHeaderIconButton.Model,
            action: @escaping ((_ button: UIControl) -> Void),
            isEnabled: Bool = true
        ) {
            self.model = .icon(model)
            self.action = action
            self.isEnabled = isEnabled
        }
    }

    public enum Title {
        case title(title: String, subtitle: NSAttributedString? = nil)
        case customView(UIView)
    }

    let title: Title
    let leftButton: LeftButton?
    let contentInsets: UIEdgeInsets
    public let isTitleCentered: Bool
    public let isCloseButtonHidden: Bool

    public static var defaultContentInsets = UIEdgeInsets(
        top: 16,
        left: 16,
        bottom: 16,
        right: 16
    )

    public init(
        title: Title,
        leftButton: LeftButton? = nil,
        contentInsets: UIEdgeInsets = Self.defaultContentInsets,
        isTitleCentered: Bool = false,
        isCloseButtonHidden: Bool = false
    ) {
        self.title = title
        self.leftButton = leftButton
        self.contentInsets = contentInsets
        self.isTitleCentered = isTitleCentered
        self.isCloseButtonHidden = isCloseButtonHidden
    }
}

public protocol TKBottomSheetContentViewController: UIViewController {
    var didUpdateHeight: (() -> Void)? { get set }

    var headerItem: TKPullCardHeaderItem? { get }
    var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)? { get set }
    func calculateHeight(withWidth width: CGFloat) -> CGFloat
}

public protocol TKBottomSheetScrollContentViewController: TKBottomSheetContentViewController {
    var scrollView: UIScrollView { get }
}
