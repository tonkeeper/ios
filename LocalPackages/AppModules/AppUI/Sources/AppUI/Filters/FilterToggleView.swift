import SwiftUI
import TKUIKit

public struct FilterToggleItem {
    let title: String
    let subtitle: String
    let isOn: Bool
    let onToggle: (Bool) -> Void

    public init(
        title: String,
        subtitle: String,
        isOn: Bool,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isOn = isOn
        self.onToggle = onToggle
    }
}

public struct FilterToggleView: View {
    private let items: [FilterToggleItem]

    public init(items: [FilterToggleItem]) {
        self.items = items
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                SetupCell(
                    content: SetupCellContent(
                        icon: nil,
                        title: item.title,
                        titleTextStyle: .label1,
                        subtitle: SetupCellContent.Subtitle(text: item.subtitle),
                        accessory: .toggle(SetupCellContent.ToggleConfig(isOn: item.isOn)),
                        showsDivider: index < items.count - 1
                    ),
                    onToggle: item.onToggle
                )
            }
        }
        .asCellsGroup(config: CellsGroupModifier.Config(horizontalPadding: 0))
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.bottomPadding)
    }
}

private enum Layout {
    static let horizontalPadding: CGFloat = 16
    static let bottomPadding: CGFloat = 16
}
