import UIKit

public extension UIBarButtonItem {
    enum CustomViewEdge {
        case leading
        case trailing
    }

    static func customView(_ view: UIView, pinnedTo edge: CustomViewEdge) -> UIBarButtonItem {
        let item = UIBarButtonItem(customView: TKBarButtonContainerView(content: view, edge: edge))
        item.hideSharedBackground()
        return item
    }

    /// `hidesSharedBackground` is ignored while an item is grouped, hence both flags.
    func hideSharedBackground() {
        guard #available(iOS 26.0, *) else { return }
        sharesBackground = false
        hidesSharedBackground = true
    }
}

/// A bar item is laid out in a slot at least 44pt wide and stretches its custom view to fill it,
/// which turns the 32pt round buttons into capsules and, mid-transition, pins them to the slot's
/// top edge. The container takes the slot's geometry so the button keeps its own.
private final class TKBarButtonContainerView: UIView {
    init(content: UIView, edge: UIBarButtonItem.CustomViewEdge) {
        super.init(frame: .zero)

        addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ]
        switch edge {
        case .leading:
            constraints += [
                content.leadingAnchor.constraint(equalTo: leadingAnchor),
                content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            ]
        case .trailing:
            constraints += [
                content.trailingAnchor.constraint(equalTo: trailingAnchor),
                content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
