import UIKit

public enum TKListContainerItemAction {
    case copy(copyValue: String?)
    case custom((_: UIView) -> Void)
}

public protocol TKListContainerItem {
    var action: TKListContainerItemAction? { get }

    func getView() -> UIView
}

public protocol TKListContainerReconfigurableItem: TKListContainerItem {
    var id: String? { get }
    func reconfigure(view: UIView)
}

public final class TKListContainerView: UIView {
    public struct Configuration {
        public let items: [TKListContainerItem]
        public let copyToastConfiguration: ToastPresenter.Configuration
        public let horizontalPadding: CGFloat

        public init(
            items: [TKListContainerItem],
            copyToastConfiguration: ToastPresenter.Configuration,
            horizontalPadding: CGFloat = 0
        ) {
            self.items = items
            self.copyToastConfiguration = copyToastConfiguration
            self.horizontalPadding = horizontalPadding
        }
    }

    public var configuration: Configuration? {
        didSet {
            setup(with: configuration)
        }
    }

    private var contentViews = [String: UIView]()

    private let stackView: UIStackView = {
        let stackView = TKPassthroughStackView()
        stackView.axis = .vertical
        return stackView
    }()

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .Background.content
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 16
        return view
    }()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        addSubview(backgroundView)
        backgroundView.addSubview(stackView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        stackView.snp.makeConstraints { make in
            make.top.bottom.equalTo(backgroundView)
            make.left.right.equalTo(backgroundView)
        }
    }

    private func setup(with configuration: Configuration?) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let horizontalPadding = configuration?.horizontalPadding ?? 0
        backgroundView.snp.updateConstraints { make in
            make.left.right.equalTo(self).inset(horizontalPadding)
        }

        guard let configuration else { return }

        for item in configuration.items.enumerated() {
            let createView = { (id: String?) in
                let contentView = item.element.getView()
                let itemView = TKListContainerItemViewContainer()
                itemView.setContentView(contentView)
                let isSeparatorVisible = (configuration.items.count - 1) != item.offset
                itemView.isSeparatorVisible = isSeparatorVisible

                if let action = item.element.action {
                    itemView.isHighlightable = true
                    itemView.addAction(UIAction(handler: { _ in
                        switch action {
                        case let .copy(copyValue):
                            guard let copyValue = copyValue else { return }
                            UIPasteboard.general.string = copyValue
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            ToastPresenter.showToast(configuration: configuration.copyToastConfiguration)
                        case let .custom(action):
                            action(itemView)
                        }
                    }), for: .touchUpInside)
                } else {
                    itemView.isHighlightable = false
                }
                if let id {
                    self.contentViews[id] = contentView
                }
                return itemView
            }

            if let reconfigurable = item as? TKListContainerReconfigurableItem {
                if let id = reconfigurable.id, let view = contentViews[id] {
                    reconfigurable.reconfigure(view: view)
                } else {
                    let view = createView(reconfigurable.id)
                    stackView.addArrangedSubview(view)
                }
            } else {
                let view = createView(nil)
                stackView.addArrangedSubview(view)
            }
        }
    }
}
