import SwiftUI
import TKUIKit

struct PerpsSheetRow {
    enum Accessory {
        case none
        case checkmark
        case chevron
    }

    let icon: UIImage
    let title: String
    let description: String
    let accessory: Accessory
    let action: () -> Void
}

struct PerpsSheetRowList: View {
    @Environment(\.tkPalette) private var palette
    let rows: [PerpsSheetRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                if index > 0 {
                    Divider()
                        .overlay(palette.separator.common)
                        .padding(.leading, Layout.inset)
                }
                row(rows[index])
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .padding(.horizontal, Layout.inset)
        .padding(.bottom, Layout.inset)
    }

    private func row(_ row: PerpsSheetRow) -> some View {
        Button(action: row.action) {
            HStack(spacing: Layout.rowSpacing) {
                SwiftUI.Image(uiImage: row.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.accentBlue)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                    Text(row.description)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                accessory(row.accessory)
            }
            .padding(.horizontal, Layout.inset)
            .padding(.top, Layout.rowTopPadding)
            .padding(.bottom, Layout.rowBottomPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func accessory(_ accessory: PerpsSheetRow.Accessory) -> some View {
        switch accessory {
        case .none:
            EmptyView()
        case .checkmark:
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.donemarkOutline)
                .renderingMode(.template)
                .foregroundStyle(.accentBlue)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
        case .chevron:
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                .renderingMode(.template)
                .foregroundStyle(.iconTertiary)
        }
    }

    private enum Layout {
        static let inset: CGFloat = 16
        static let cornerRadius: CGFloat = 16
        static let rowSpacing: CGFloat = 16
        static let rowTopPadding: CGFloat = 14
        static let rowBottomPadding: CGFloat = 15
        static let iconSize: CGFloat = 28
    }
}
