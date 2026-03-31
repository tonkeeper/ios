import UIKit

public final class TKTabsView: UIView {
    public struct Item {
        public let title: String
        public let isSelectable: Bool
        public let selectionColor: UIColor?
        public let selectionBorderColor: UIColor?
        public let borderWidth: CGFloat
        public let action: () -> Void

        public init(
            title: String,
            isSelectable: Bool,
            selectionColor: UIColor? = nil,
            selectionBorderColor: UIColor? = nil,
            borderWidth: CGFloat = 0,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.isSelectable = isSelectable
            self.selectionColor = selectionColor
            self.selectionBorderColor = selectionBorderColor
            self.borderWidth = borderWidth
            self.action = action
        }
    }

    public var selectedItem: Item? {
        didSet {
            if
                let selectedItem,
                let button = tabButtons.first(where: { $0.title == selectedItem.title })
            {
                didTapItem(item: selectedItem, button: button)
            } else {
                tabButtons.forEach { $0.isSelected = false }
            }
        }
    }

    public var items = [Item]() {
        didSet {
            tabButtons = []
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for item in items {
                let button = TKTabButton()
                button.title = item.title
                button.selectionColor = item.selectionColor
                button.selectionBorderColor = item.selectionBorderColor
                button.borderWidth = item.borderWidth
                button.action = { [weak self] in
                    self?.didTapItem(item: item, button: button)
                }
                stackView.addArrangedSubview(button)
                tabButtons.append(button)
            }
        }
    }

    private var tabButtons = [TKTabButton]()
    private let stackView = UIStackView()
    private let scrollView = UIScrollView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 56)
    }

    private func setup() {
        backgroundColor = .Background.page

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        stackView.alignment = .center
        stackView.spacing = 8

        addSubview(scrollView)
        scrollView.addSubview(stackView)

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(self).offset(8)
            make.left.right.bottom.equalTo(self).inset(16)
        }
        stackView.snp.makeConstraints { make in
            make.top.equalTo(scrollView)
            make.left.bottom.equalTo(scrollView)
            make.right.lessThanOrEqualTo(scrollView)
            make.height.equalTo(scrollView)
        }
    }

    private func didTapItem(item: Item, button: TKTabButton) {
        if item.isSelectable {
            for tabButton in tabButtons {
                tabButton.isSelected = tabButton === button
            }
        }
        // If item is not selectable, preserve current selection state
        item.action()
    }
}

private final class TKTabButton: UIControl {
    private let button = TKButton()

    override var isSelected: Bool {
        didSet {
            button.isSelected = isSelected
        }
    }

    var action: (() -> Void)? {
        didSet {
            updateButtonConfiguration()
        }
    }

    var title: String? {
        didSet {
            updateButtonConfiguration()
        }
    }

    var selectionColor: UIColor? {
        didSet {
            updateButtonConfiguration()
        }
    }

    var selectionBorderColor: UIColor? {
        didSet {
            updateButtonConfiguration()
        }
    }

    var borderWidth: CGFloat = 0 {
        didSet {
            updateButtonConfiguration()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateButtonConfiguration() {
        var configuration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .small)
        configuration.backgroundColors[.selected] = selectionColor ?? .Button.primaryBackgroundHighlighted
        configuration.borderColors[.selected] = selectionBorderColor
        configuration.borderWidth = borderWidth
        configuration.content.title = .plainString(title ?? "")
        configuration.action = { [weak self] in
            self?.action?()
        }
        button.configuration = configuration
    }

    private func setup() {
        addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
