import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct AmountInputSwiftUIView: View {
    @ObservedObject var viewModel: AmountInputSwiftUIViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Layout.valueSpacing) {
                inputRow
                convertedButton
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.cardHeight)
            .background(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                    .fill(.backgroundContent)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }

            if viewModel.showsBalance {
                balanceRow
                    .frame(height: Layout.balanceHeight)
            }
        }
    }
}

private extension AmountInputSwiftUIView {
    var inputRow: some View {
        GeometryReader { proxy in
            HStack(spacing: Layout.symbolSpacing) {
                TextField("0", text: textBinding)
                    .font(Font(UIFont.tkMedium(size: Layout.inputFontSize, features: .display)))
                    .foregroundStyle(.textPrimary)
                    .tint(.accentBlue)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(Layout.inputMinimumScaleFactor)
                    .focused($isFocused)
                    .frame(width: inputTextWidth(availableWidth: proxy.size.width))

                inputSymbolView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Layout.inputRowHeight)
    }

    var textBinding: Binding<String> {
        Binding(
            get: { viewModel.text },
            set: { viewModel.setText($0) }
        )
    }

    func inputTextWidth(availableWidth: CGFloat) -> CGFloat {
        let displayText = viewModel.text.isEmpty ? "0" : viewModel.text
        let symbolWidth: CGFloat = {
            switch viewModel.inputSymbol {
            case .icon:
                Layout.inputSymbolIconSize.width
            case let .text(symbol):
                textWidth(symbol, font: TKTextStyle.num2.font)
            }
        }()
        let available = max(
            Layout.inputMinimumWidth,
            availableWidth - Layout.inputHorizontalMargin * 2 - symbolWidth - Layout.symbolSpacing
        )
        let width = min(
            available,
            textWidth(displayText, font: .tkMedium(size: Layout.inputFontSize, features: .display)) + Layout.caretPadding
        )
        return max(width, Layout.inputMinimumWidth)
    }

    func textWidth(_ string: String, font: UIFont) -> CGFloat {
        ceil((string as NSString).size(withAttributes: [.font: font]).width)
    }

    @ViewBuilder
    var inputSymbolView: some View {
        switch viewModel.inputSymbol {
        case let .icon(image):
            SwiftUI.Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.iconSecondary)
                .frame(
                    width: Layout.inputSymbolIconSize.width,
                    height: Layout.inputSymbolIconSize.height
                )
        case let .text(symbol):
            Text(symbol)
                .textStyle(.num2)
                .foregroundStyle(.textSecondary)
                .offset(y: Layout.inputSymbolTextOffset)
        }
    }

    @ViewBuilder
    var convertedButton: some View {
        if !viewModel.converted.isHidden {
            Button(action: viewModel.toggle) {
                convertedContent
                    .padding(.vertical, Layout.convertedVerticalPadding)
                    .padding(.horizontal, Layout.convertedHorizontalPadding)
                    .background(
                        Capsule(style: .continuous)
                            .strokeBorder(.buttonTertiaryBackground, lineWidth: Layout.convertedBorderWidth)
                    )
            }
            .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
            .disabled(!viewModel.converted.isSwitchEnabled)
        }
    }

    @ViewBuilder
    var convertedContent: some View {
        if viewModel.converted.showsShimmer {
            ShimmerSwiftUIView(
                config: ShimmerSwiftUIView.Config(
                    color: .backgroundContentTint,
                    cornerRadius: .capsule
                )
            )
            .frame(
                width: Layout.convertedShimmerSize.width,
                height: Layout.convertedShimmerSize.height
            )
        } else {
            HStack(spacing: Layout.symbolSpacing) {
                Text(viewModel.converted.text)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)

                convertedSymbolView

                if viewModel.converted.showsSwitchIcon {
                    SwiftUI.Image.TKUIKit.Icons.Size16.switch
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Layout.convertedIconSize, height: Layout.convertedIconSize)
                        .foregroundStyle(.iconSecondary)
                        .padding(.leading, Layout.switchIconLeadingPadding)
                }
            }
        }
    }

    @ViewBuilder
    var convertedSymbolView: some View {
        switch viewModel.converted.symbol {
        case let .icon(image):
            SwiftUI.Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.iconSecondary)
                .frame(width: Layout.convertedIconSize, height: Layout.convertedIconSize)
        case let .text(symbol):
            Text(symbol)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
        }
    }

    var balanceRow: some View {
        HStack(spacing: 0) {
            if viewModel.balance.showsMaxButton {
                maxButton
            }

            Spacer(minLength: 0)

            Text(viewModel.balance.text)
                .textStyle(.body2)
                .foregroundStyle(viewModel.balance.isError ? .accentRed : .textSecondary)
                .lineLimit(1)
        }
    }

    var maxButton: some View {
        Button(action: viewModel.tapMax) {
            Text(TKLocales.Common.Numbers.max)
                .textStyle(.label2)
                .foregroundStyle(
                    viewModel.balance.isMaxSelected
                        ? .buttonPrimaryForeground
                        : .buttonSecondaryForeground
                )
                .padding(.vertical, Layout.maxVerticalPadding)
                .padding(.horizontal, Layout.maxHorizontalPadding)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            viewModel.balance.isMaxSelected
                                ? TKColor.buttonPrimaryBackground
                                : TKColor.buttonSecondaryBackground
                        )
                )
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
    }

    enum Layout {
        static let cardHeight: CGFloat = 188
        static let cardCornerRadius: CGFloat = 16
        static let valueSpacing: CGFloat = 8
        static let inputRowHeight: CGFloat = 70
        static let inputFontSize: CGFloat = 40
        static let inputMinimumScaleFactor: CGFloat = 0.5
        static let inputHorizontalMargin: CGFloat = 16
        static let inputMinimumWidth: CGFloat = 28
        static let caretPadding: CGFloat = 4
        static let inputSymbolIconSize = CGSize(width: 28, height: 36)
        static let inputSymbolTextOffset: CGFloat = 5
        static let symbolSpacing: CGFloat = 4
        static let convertedVerticalPadding: CGFloat = 6
        static let convertedHorizontalPadding: CGFloat = 16
        static let convertedBorderWidth: CGFloat = 1.5
        static let convertedIconSize: CGFloat = 16
        static let convertedShimmerSize = CGSize(width: 96, height: 24)
        static let switchIconLeadingPadding: CGFloat = 4
        static let balanceHeight: CGFloat = 48
        static let maxVerticalPadding: CGFloat = 5
        static let maxHorizontalPadding: CGFloat = 16
    }
}
