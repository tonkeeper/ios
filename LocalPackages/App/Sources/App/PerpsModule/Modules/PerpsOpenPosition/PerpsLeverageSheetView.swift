import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsLeverageSheetView: View {
    @ObservedObject var viewModel: PerpsLeverageSheetViewModel

    var body: some View {
        VStack(spacing: Layout.spacing) {
            pickerCard
            liquidationRow
            Text(TKLocales.Perps.OpenPosition.leverageRisk)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Layout.riskTopPadding)
                .padding(.bottom, Layout.riskBottomPadding)
            applyButton
        }
        .padding(Layout.inset)
    }

    private var pickerCard: some View {
        VStack(spacing: Layout.cardSpacing) {
            ZStack {
                Text(viewModel.leverageText)
                    .font(Font(UIFont.tkMedium(size: 40, features: .display)))
                    .foregroundStyle(.textPrimary)
                HStack {
                    ButtonView(config: .init(
                        title: TKLocales.Perps.OpenPosition.minShort,
                        size: .small,
                        appearance: .tertiary,
                        action: { viewModel.setMin() }
                    ))
                    Spacer()
                    ButtonView(config: .init(
                        title: TKLocales.Perps.OpenPosition.max,
                        size: .small,
                        appearance: .tertiary,
                        action: { viewModel.setMax() }
                    ))
                }
            }
            TKValueRulerView(
                range: viewModel.minLeverage ... viewModel.maxLeverage,
                value: Binding(
                    get: { Int(viewModel.leverage.rounded()) },
                    set: { viewModel.setLeverage(Double($0)) }
                )
            )
        }
        .padding(.vertical, Layout.cardVPadding)
        .padding(.horizontal, Layout.inset)
        .frame(maxWidth: .infinity)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }

    private var liquidationRow: some View {
        HStack(spacing: Layout.rowSpacing) {
            Text(TKLocales.Perps.OpenPosition.liquidationPrice)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.informationCircle)
                .renderingMode(.template)
                .foregroundStyle(.iconSecondary)
            Spacer()
            Text(viewModel.liquidationText ?? "—")
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, Layout.rowVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }

    private var applyButton: some View {
        ButtonView(config: .init(
            title: TKLocales.Perps.OpenPosition.apply,
            size: .large,
            layoutMode: .fill,
            appearance: .primary,
            action: { viewModel.apply() }
        ))
    }

    private enum Layout {
        static let inset: CGFloat = 16
        static let spacing: CGFloat = 16
        static let cardSpacing: CGFloat = 16
        static let cardVPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 16
        static let rowSpacing: CGFloat = 8
        static let rowVerticalPadding: CGFloat = 14
        static let riskTopPadding: CGFloat = -2
        static let riskBottomPadding: CGFloat = -1
    }
}
