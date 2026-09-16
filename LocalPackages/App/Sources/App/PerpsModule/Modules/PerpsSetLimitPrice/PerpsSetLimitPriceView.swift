import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsSetLimitPriceView: View {
    @Environment(\.tkPalette) private var palette
    @ObservedObject var viewModel: PerpsSetLimitPriceViewModel
    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: Layout.blockSpacing) {
                    amountCard
                    quickFills
                    warningLabel
                }
                .padding(.top, Layout.blockSpacing)
            }
            .tkImmediateButtonPresses()
            setButton
        }
        .background(.backgroundPage)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            viewModel.onAppear()
            DispatchQueue.main.async {
                amountFocused = true
            }
        }
        .onDisappear { viewModel.onDisappear() }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            VStack(spacing: -1) {
                Text(TKLocales.Perps.SetLimitPrice.title)
                    .textStyle(.h3)
                    .foregroundStyle(.textPrimary)
                Text("\(TKLocales.Perps.OpenPosition.price) \(viewModel.referencePriceText)")
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }
            HStack {
                PerpsCircleButton(icon: .TKUIKit.Icons.Size16.chevronLeft, action: viewModel.back)
                Spacer()
                PerpsCircleButton(icon: .TKUIKit.Icons.Size16.close, action: viewModel.close)
            }
        }
        .padding(.horizontal, Layout.inset)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
    }

    // MARK: Amount

    private var amountCard: some View {
        PerpsAmountField(
            text: Binding(get: { viewModel.amountText }, set: { viewModel.setAmount($0) }),
            focused: $amountFocused,
            prefix: viewModel.fieldPrefix,
            suffix: viewModel.fieldSuffix
        ) {
            offsetChip
        }
        .padding(.horizontal, Layout.inset)
    }

    @ViewBuilder private var warningLabel: some View {
        if let warningText = viewModel.warningText {
            Text(warningText)
                .textStyle(.body2)
                .foregroundStyle(.accentRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.inset)
                .padding(.top, -2)
        }
    }

    private var offsetChip: some View {
        Button(action: viewModel.toggleInputMode) {
            HStack(spacing: Layout.chipSpacing) {
                Text(viewModel.chipText)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.swapVertical)
                    .renderingMode(.template)
                    .foregroundStyle(.iconSecondary)
            }
            .padding(.horizontal, Layout.inset)
            .padding(.vertical, Layout.chipVPadding)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.chipCornerRadius)
                    .stroke(palette.button.tertiaryBackground, lineWidth: Layout.chipBorder)
            )
        }
    }

    // MARK: Quick-fills

    private var quickFills: some View {
        HStack(spacing: Layout.quickFillSpacing) {
            ForEach(viewModel.quickFills) { item in
                ButtonView(config: .init(
                    title: item.title,
                    size: .small,
                    layoutMode: .fill,
                    appearance: item.isActive ? .tertiary : .secondary,
                    action: { viewModel.applyQuickFill(item.fill) }
                ))
            }
        }
        .padding(.horizontal, Layout.inset)
    }

    // MARK: Action

    private var setButton: some View {
        ButtonView(config: .init(
            title: TKLocales.Perps.SetLimitPrice.set,
            size: .large,
            layoutMode: .fill,
            appearance: .primary,
            action: viewModel.setLimit
        ))
        .disabled(!viewModel.isSetEnabled)
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, Layout.blockSpacing)
    }

    private enum Layout {
        static let inset: CGFloat = 16
        static let blockSpacing: CGFloat = 16
        static let headerTopPadding: CGFloat = 18
        static let headerBottomPadding: CGFloat = 14
        static let chipSpacing: CGFloat = 4
        static let chipVPadding: CGFloat = 6
        static let chipCornerRadius: CGFloat = 24
        static let chipBorder: CGFloat = 1.5
        static let quickFillSpacing: CGFloat = 4
    }
}
