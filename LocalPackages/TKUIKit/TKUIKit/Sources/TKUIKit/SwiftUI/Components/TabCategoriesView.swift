import SwiftUI
import UIKit

public struct TabCategoriesView<Selection: Hashable>: View {
    private let items: [Item]
    private let shimmer: Bool
    private let initialSelection: Selection
    private let onSelectionChange: (Selection) -> Void
    private let contentInsets: EdgeInsets
    private let style: TabCategoryView.Style

    @State private var selectedItem: Selection

    public init(
        items: [Item],
        initialSelection: Selection,
        onSelectionChange: @escaping (Selection) -> Void,
        style: TabCategoryView.Style = .primary,
        shimmer: Bool = false,
        insetsModifier: (inout EdgeInsets) -> Void = { _ in }
    ) {
        self.items = items
        self.initialSelection = initialSelection
        self.onSelectionChange = onSelectionChange
        self.shimmer = shimmer
        self.style = style
        self.contentInsets = {
            var insets = Layout.insets
            insetsModifier(&insets)
            return insets
        }()
        _selectedItem = State(initialValue: initialSelection)
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Layout.itemSpacing) {
                ForEach(items) { item in
                    TabCategoryView(
                        title: item.title,
                        image: item.image,
                        isSelected: item.id == selectedItem,
                        style: item.style ?? style,
                        accessibilityIdentifier: item.accessibilityIdentifier
                    ) {
                        if item.isSelectable {
                            selectedItem = item.id
                        }
                        onSelectionChange(item.id)
                    }
                    .shimmer(shimmer, config: .init(cornerRadius: .capsule))
                }
                Spacer(minLength: 0)
            }
            .onChange(of: initialSelection) { initialSelection in
                guard selectedItem != initialSelection else { return }
                selectedItem = initialSelection
            }
            .padding(contentInsets)
        }
        .tkImmediateButtonPresses()
        .frame(maxWidth: .infinity)
    }
}

public extension TabCategoriesView {
    struct Item: Identifiable {
        public var id: Selection
        public var title: String
        public var image: UIImage?
        public var isSelectable: Bool
        public var style: TabCategoryView.Style?
        public var accessibilityIdentifier: String?

        public init(
            id: Selection,
            title: String,
            image: UIImage? = nil,
            isSelectable: Bool = true,
            style: TabCategoryView.Style? = nil,
            accessibilityIdentifier: String? = nil
        ) {
            self.id = id
            self.title = title
            self.image = image
            self.isSelectable = isSelectable
            self.style = style
            self.accessibilityIdentifier = accessibilityIdentifier
        }
    }
}

extension TabCategoriesView {
    private enum Layout {
        static var itemSpacing: CGFloat {
            6
        }

        static var insets: EdgeInsets {
            EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16)
        }
    }
}
