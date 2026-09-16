import SwiftUI
import UIKit

public final class TKTabsView: UIView {
    public struct Item {
        public let title: String
        public let image: UIImage?
        public let isSelectable: Bool
        public let action: () -> Void

        public init(
            title: String,
            image: UIImage? = nil,
            isSelectable: Bool,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.image = image
            self.isSelectable = isSelectable
            self.action = action
        }
    }

    public var selectedItem: Item? {
        didSet {
            guard let selectedItem else {
                selectedItemTitle = nil
                updateRootView()
                return
            }

            selectedItemTitle = selectedItem.title
            updateRootView()
            selectedItem.action()
        }
    }

    public var items = [Item]() {
        didSet {
            if selectedItemTitle == nil {
                selectedItemTitle = items.first?.title
            } else if items.contains(where: { $0.title == selectedItemTitle }) == false {
                selectedItemTitle = items.first?.title
            }
            updateRootView()
        }
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 52)
    }

    private var selectedItemTitle: String?
    private var hostingController: TKHostingController<AnyView>?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .Background.page
    }

    private func updateRootView() {
        let tabItems = items.map { item in
            TabCategoriesView<String>.Item(
                id: item.title,
                title: item.title,
                image: item.image,
                isSelectable: item.isSelectable
            )
        }

        let initialSelection = selectedItemTitle ?? tabItems.first?.id ?? ""
        let rootView = AnyView(
            TabCategoriesView(
                items: tabItems,
                initialSelection: initialSelection,
                onSelectionChange: { [weak self] title in
                    self?.didSelect(title: title)
                }
            )
            .background(.backgroundPage)
        )

        if let hostingController {
            hostingController.content = rootView
            return
        }

        let hostingController = TKHostingController(content: rootView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        self.hostingController = hostingController
    }

    private func didSelect(title: String) {
        guard let item = items.first(where: { $0.title == title }) else { return }

        if item.isSelectable {
            selectedItemTitle = title
            updateRootView()
        }

        item.action()
    }
}
