import TKUIKit
import UIKit

final class HistoryCellContentView: UIView, ConfigurableView, ReusableView {
    var actionViews = [HistoryCellActionView]()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let height = actionViews.reduce(CGFloat(0)) { partialResult, view in
            partialResult + view.sizeThatFits(size).height
        }
        return CGSize(width: size.width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var originY: CGFloat = 0
        for view in actionViews {
            let size = view.sizeThatFits(CGSize(width: bounds.width, height: 0))
            view.frame.origin = CGPoint(x: 0, y: originY)
            view.frame.size = size
            originY = view.frame.maxY
        }

        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(.init(width: bounds.width, height: 0)).height)
    }

    struct Model {
        struct Action {
            let configuration: HistoryCellActionView.Model
            let action: () -> Void
        }

        let actions: [Action]
    }

    func configure(model: Model) {
        var actionViews = [HistoryCellActionView]()
        for (index, view) in self.actionViews.enumerated() {
            guard index < model.actions.count else {
                view.removeFromSuperview()
                continue
            }
            actionViews.append(view)
        }

        for (index, action) in model.actions.enumerated() {
            let view: HistoryCellActionView
            if index < actionViews.count {
                view = actionViews[index]
            } else {
                view = HistoryCellActionView()
                actionViews.append(view)
                addSubview(view)
            }
            view.configure(model: action.configuration)
            view.isSeparatorVisible = index < model.actions.count - 1
            view.enumerateEventHandlers { action, _, event, _ in
                if let action = action {
                    view.removeAction(action, for: event)
                }
            }
            view.addAction(UIAction(handler: { _ in
                action.action()
            }), for: .touchUpInside)
        }

        self.actionViews = actionViews
        setNeedsLayout()
    }

    func prepareForReuse() {
        actionViews.forEach { $0.prepareForReuse() }
    }
}

private extension HistoryCellContentView {
    func setup() {
        layer.masksToBounds = true
        layer.cornerRadius = 16
    }
}
