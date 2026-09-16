import SnapKit
import UIKit

public final class TKTabBarView: UIView {
    public struct Item: Equatable {
        public let title: String
        public let image: UIImage?

        public init(title: String, image: UIImage?) {
            self.title = title
            self.image = image
        }
    }

    public var didSelectItem: ((Int) -> Void)?
    public var didLongPressItem: ((Int) -> Void)?

    public var items = [Item]() {
        didSet {
            guard items != oldValue else { return }
            rebuildItemViews()
        }
    }

    public var selectedIndex = 0 {
        didSet { updateSelection() }
    }

    public func iconContainer(at index: Int) -> UIView? {
        guard itemViews.indices.contains(index) else { return nil }
        return itemViews[index].iconContainer
    }

    public func itemView(at index: Int) -> UIView? {
        guard itemViews.indices.contains(index) else { return nil }
        return itemViews[index]
    }

    public func setStaticIconHidden(_ isHidden: Bool, at index: Int) {
        guard itemViews.indices.contains(index) else { return }
        itemViews[index].isStaticIconHidden = isHidden
    }

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()

    private var itemViews = [TKTabBarItemView]()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension TKTabBarView {
    func setup() {
        backgroundColor = .Background.page

        addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.top.equalTo(self).offset(CGFloat.itemTopOffset)
            make.left.equalTo(self).offset(CGFloat.itemsHorizontalOffset)
            make.right.equalTo(self).offset(-CGFloat.itemsHorizontalOffset)
            make.height.equalTo(CGFloat.itemHeight)
        }

        addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        )
    }

    func rebuildItemViews() {
        for itemView in itemViews {
            stackView.removeArrangedSubview(itemView)
            itemView.removeFromSuperview()
        }

        itemViews = items.enumerated().map { index, item in
            let itemView = TKTabBarItemView()
            itemView.configure(title: item.title, image: item.image)
            itemView.onSelect = { [weak self] in self?.didSelectItem?(index) }
            stackView.addArrangedSubview(itemView)
            return itemView
        }

        updateSelection()
    }

    func updateSelection() {
        for (index, itemView) in itemViews.enumerated() {
            itemView.isItemSelected = index == selectedIndex
        }
    }

    @objc
    func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let location = recognizer.location(in: self)
        guard let index = itemViews.firstIndex(where: { $0.frame.contains(convert(location, to: stackView)) })
        else { return }
        didLongPressItem?(index)
    }
}

private extension CGFloat {
    static let itemTopOffset: CGFloat = 6
    static let itemsHorizontalOffset: CGFloat = 16
    static let itemHeight: CGFloat = 48
}
