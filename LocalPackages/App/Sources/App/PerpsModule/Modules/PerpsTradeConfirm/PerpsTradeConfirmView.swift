import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsTradeConfirmView: View {
    @Environment(\.tkPalette) private var palette
    @ObservedObject var viewModel: PerpsTradeConfirmViewModel

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(spacing: 0) {
                    icon
                        .padding(.bottom, Layout.iconBottomPadding)
                    titleBlock
                        .padding(.horizontal, Layout.inset)
                        .padding(.bottom, Layout.titleBottomPadding)
                    rowsCard
                }
                .padding(.horizontal, Layout.inset)
                .padding(.top, Layout.contentTopPadding)
            }
            .tkImmediateButtonPresses()
            slider
        }
        .background(.backgroundPage)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private var navBar: some View {
        HStack {
            PerpsCircleButton(icon: .TKUIKit.Icons.Size16.chevronLeft, action: viewModel.back)
            Spacer()
            PerpsCircleButton(icon: .TKUIKit.Icons.Size16.close, action: viewModel.close)
        }
        .padding(.horizontal, Layout.inset)
        .padding(.top, Layout.navTopPadding)
    }

    @ViewBuilder
    private var icon: some View {
        if let iconURL = viewModel.iconURL {
            AssetAvatarView(imageSource: .url(iconURL), size: .extraLarge)
        } else {
            Text(viewModel.iconLetter)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .background(.backgroundContentTint)
                .clipShape(Circle())
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 0) {
            Text(TKLocales.Perps.Confirm.title)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
            Text(viewModel.titleText)
                .textStyle(.h3)
                .foregroundStyle(.textPrimary)
        }
    }

    private var rowsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().overlay(palette.separator.common)
                        .padding(.leading, Layout.inset)
                }
                rowView(row)
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }

    @ViewBuilder
    private func rowView(_ row: PerpsTradeConfirmViewModel.Row) -> some View {
        if row.showsChevron {
            Button(action: viewModel.editAutoClose) {
                rowContent(row)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isConfirmationEnabled)
        } else {
            rowContent(row)
        }
    }

    private func rowContent(_ row: PerpsTradeConfirmViewModel.Row) -> some View {
        HStack(alignment: .top) {
            Text(row.title)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: -2) {
                valueLabel(row)
                if let subValue = row.subValue {
                    Text(subValue)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
            }
            if row.showsChevron {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                    .foregroundStyle(.iconTertiary)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, Layout.rowVerticalPadding)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func valueLabel(_ row: PerpsTradeConfirmViewModel.Row) -> some View {
        if let parts = row.valueParts, !parts.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    Text(part.text)
                        .textStyle(.label1)
                        .foregroundStyle(valueColor(part.tone))
                }
            }
        } else {
            Text(row.value)
                .textStyle(.label1)
                .foregroundStyle(valueColor(row.tone))
        }
    }

    private func valueColor(_ tone: PerpsTradeConfirmViewModel.Tone) -> Color {
        switch tone {
        case .neutral: palette.text.primary
        case .positive: palette.accent.green
        case .negative: palette.accent.red
        case .tertiary: palette.text.tertiary
        }
    }

    private var slider: some View {
        TKSwipeToConfirmView(
            title: TKLocales.Perps.Confirm.confirm,
            subtitle: TKLocales.Perps.Confirm.swipe,
            isEnabled: viewModel.isConfirmationEnabled,
            handleAccessibilityIdentifier: "perps_confirm_swipe",
            onConfirm: viewModel.confirm
        )
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, Layout.spacing)
    }

    private enum Layout {
        static let inset: CGFloat = 16
        static let spacing: CGFloat = 16
        static let cornerRadius: CGFloat = 16
        static let navTopPadding: CGFloat = 12
        static let iconSize: CGFloat = 96
        static let contentTopPadding: CGFloat = 16
        static let iconBottomPadding: CGFloat = 18
        static let titleBottomPadding: CGFloat = 30
        static let rowVerticalPadding: CGFloat = 14
    }
}
