import SwiftUI
import TKUIKit

struct PerpsPositionRowView: View {
    let position: PerpsPositionRowItem

    var body: some View {
        HStack(spacing: 0) {
            icon

            HStack(spacing: 0) {
                Text(position.symbol)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let leverage = position.leverageText {
                    TKTagSwiftUIView(config: .tag(text: leverage))
                }
                TKTagSwiftUIView(config: .accentTag(
                    text: position.sideText,
                    accent: position.isLong ? .accentGreen : .accentRed
                ))
            }
            .padding(.leading, Layout.cellPadding)

            Spacer(minLength: Layout.cellPadding)

            VStack(alignment: .trailing, spacing: 0) {
                Text(position.valueText)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                Text(position.pnlText)
                    .textStyle(.body2)
                    .foregroundStyle(position.isPnlPositive ? TKColor.accentGreen : TKColor.accentRed)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, Layout.cellPadding)
        .padding(.vertical, Layout.rowVerticalPadding)
    }

    @ViewBuilder
    private var icon: some View {
        if let iconURL = position.iconURL {
            AssetAvatarView(imageSource: .url(iconURL), size: .small)
        } else {
            ZStack {
                Circle()
                    .fill(.backgroundContentTint)
                Text(String(position.symbol.prefix(1)))
                    .textStyle(.label2)
                    .foregroundStyle(.textSecondary)
            }
            .frame(width: Layout.iconSide, height: Layout.iconSide)
        }
    }
}

private extension PerpsPositionRowView {
    enum Layout {
        static let cellPadding: CGFloat = 16
        static let iconSide: CGFloat = 44
        static let rowVerticalPadding: CGFloat = 16
    }
}
