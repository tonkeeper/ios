import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsAutoCloseSheetView: View {
    @Environment(\.tkPalette) private var palette
    @ObservedObject var viewModel: PerpsAutoCloseSheetViewModel

    private enum Field: Hashable {
        case takeProfitPercent, takeProfitPrice
        case stopLossPercent, stopLossPrice
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            takeProfitSection
            stopLossSection
            if let errorText = viewModel.submitErrorText {
                warningLabel(errorText)
                    .padding(.top, Layout.submitErrorTopPadding)
            }
            setButton
        }
        .padding(.horizontal, Layout.inset)
        .padding(.top, Layout.contentTopPadding)
        .padding(.bottom, Layout.inset)
    }

    private var takeProfitSection: some View {
        section(
            title: TKLocales.Perps.OpenPosition.takeProfitWhen,
            percentField: .takeProfitPercent,
            priceField: .takeProfitPrice,
            percentPlaceholder: TKLocales.Perps.OpenPosition.profitPercent,
            percentText: Binding(get: { viewModel.takeProfitPercentText }, set: { viewModel.setTakeProfitPercent($0) }),
            priceText: Binding(get: { viewModel.takeProfitPriceText }, set: { viewModel.setTakeProfitPrice($0) }),
            presets: viewModel.takeProfitPresets,
            sign: "+",
            warningText: viewModel.takeProfitWarningText,
            onPreset: viewModel.applyTakeProfitPreset
        )
    }

    private var stopLossSection: some View {
        section(
            title: TKLocales.Perps.OpenPosition.stopLossWhen,
            percentField: .stopLossPercent,
            priceField: .stopLossPrice,
            percentPlaceholder: TKLocales.Perps.OpenPosition.lossPercent,
            percentText: Binding(get: { viewModel.stopLossPercentText }, set: { viewModel.setStopLossPercent($0) }),
            priceText: Binding(get: { viewModel.stopLossPriceText }, set: { viewModel.setStopLossPrice($0) }),
            presets: viewModel.stopLossPresets,
            sign: "−",
            warningText: viewModel.stopLossWarningText,
            onPreset: viewModel.applyStopLossPreset
        )
    }

    private func section(
        title: String,
        percentField: Field,
        priceField: Field,
        percentPlaceholder: String,
        percentText: Binding<String>,
        priceText: Binding<String>,
        presets: [Double],
        sign: String,
        warningText: String?,
        onPreset: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.fieldSpacing) {
            Text(title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
            HStack(spacing: Layout.fieldGap) {
                inputField(field: percentField, placeholder: percentPlaceholder, rawText: percentText, prefix: sign, suffix: "%")
                inputField(field: priceField, placeholder: TKLocales.Perps.OpenPosition.priceField, rawText: priceText, prefix: "$", suffix: nil)
            }
            if let warningText {
                warningLabel(warningText)
            }
            HStack(spacing: Layout.presetSpacing) {
                ForEach(presets, id: \.self) { percent in
                    presetTab(
                        title: "\(sign) \(Int(percent)) %",
                        isSelected: isPresetSelected(percent, percentText.wrappedValue),
                        action: { onPreset(percent) }
                    )
                }
            }
            .padding(.top, Layout.presetsTopPadding)
        }
    }

    private func inputField(
        field: Field,
        placeholder: String,
        rawText: Binding<String>,
        prefix: String,
        suffix: String?
    ) -> some View {
        let isEditing = focusedField == field
        let hasValue = !rawText.wrappedValue.isEmpty
        return HStack(spacing: Layout.adornmentSpacing) {
            if hasValue {
                fieldText(prefix)
            }
            TextField(placeholder, text: Binding(
                get: { isEditing ? rawText.wrappedValue : PerpsFormatting.plain(rawText.wrappedValue) },
                set: { if isEditing { rawText.wrappedValue = $0 } }
            ))
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: field)
            .textStyle(.body1)
            .foregroundStyle(.textPrimary)
            .fixedSize()
            if hasValue, let suffix {
                fieldText(suffix)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, Layout.verticalInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .contentShape(Rectangle())
        .onTapGesture { focusedField = field }
    }

    private func warningLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(.body2)
            .foregroundStyle(.accentRed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, Layout.warningBottomPadding)
    }

    private func fieldText(_ text: String) -> some View {
        Text(text)
            .textStyle(.body1)
            .foregroundStyle(.textPrimary)
    }

    private func presetTab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .textStyle(.label2)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Layout.presetVPadding)
                .background {
                    RoundedRectangle(cornerRadius: Layout.presetCornerRadius)
                        .fill(isSelected ? palette.background.contentTint : Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.presetCornerRadius)
                        .strokeBorder(
                            palette.background.contentTint,
                            lineWidth: isSelected ? 0 : Layout.presetBorderWidth
                        )
                }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func isPresetSelected(_ percent: Double, _ text: String) -> Bool {
        guard let value = Double(text) else { return false }
        return abs(value - percent) < 0.0001
    }

    private var setButton: some View {
        ZStack {
            ButtonView(config: .init(
                title: viewModel.isSubmitting ? "" : TKLocales.Perps.OpenPosition.set,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: viewModel.apply
            ))
            .disabled(!viewModel.isApplyEnabled || viewModel.isSubmitting)
            if viewModel.isSubmitting {
                CircularLoader(mode: .indeterminate, preset: .small)
            }
        }
        .padding(.top, Layout.buttonTopPadding)
    }

    private enum Layout {
        static let inset: CGFloat = 16
        static let verticalInset: CGFloat = 14
        static let contentTopPadding: CGFloat = 14
        static let sectionSpacing: CGFloat = 16
        static let fieldSpacing: CGFloat = 10
        static let fieldGap: CGFloat = 8
        static let adornmentSpacing: CGFloat = 4
        static let cornerRadius: CGFloat = 16
        static let presetSpacing: CGFloat = 4
        static let presetsTopPadding: CGFloat = 2
        static let presetVPadding: CGFloat = 5
        static let presetCornerRadius: CGFloat = 16
        static let presetBorderWidth: CGFloat = 1.5
        static let warningBottomPadding: CGFloat = -1
        static let submitErrorTopPadding: CGFloat = 2
        static let buttonTopPadding: CGFloat = 7
    }
}
