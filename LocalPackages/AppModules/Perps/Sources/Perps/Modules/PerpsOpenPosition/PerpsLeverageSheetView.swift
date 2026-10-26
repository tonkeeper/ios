import SwiftUI
import TKLocalize
import TKUIKit

@MainActor
public protocol PerpsLeverageSheetViewModeling: ObservableObject {
    var leverage: Double { get }
    var liquidationText: String? { get }
    var leverageText: String { get }
    var minLeverage: Int { get }
    var maxLeverage: Int { get }

    func setLeverage(_ value: Double)
    func setMin()
    func setMax()
    func apply()
}

public struct PerpsLeverageSheetView<ViewModel: PerpsLeverageSheetViewModeling>: View {
    @ObservedObject private var viewModel: ViewModel

    public init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: PerpsLeverageSheetLayout.spacing) {
            pickerCard
            liquidationRow
            Text(TKLocales.Perps.OpenPosition.leverageRisk)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, PerpsLeverageSheetLayout.riskTopPadding)
                .padding(.bottom, PerpsLeverageSheetLayout.riskBottomPadding)
            applyButton
        }
        .padding(PerpsLeverageSheetLayout.inset)
    }

    private var pickerCard: some View {
        VStack(spacing: PerpsLeverageSheetLayout.cardSpacing) {
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
        .padding(.vertical, PerpsLeverageSheetLayout.cardVPadding)
        .padding(.horizontal, PerpsLeverageSheetLayout.inset)
        .frame(maxWidth: .infinity)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: PerpsLeverageSheetLayout.cornerRadius))
    }

    private var liquidationRow: some View {
        HStack(spacing: PerpsLeverageSheetLayout.rowSpacing) {
            Text(TKLocales.Perps.OpenPosition.liquidationPrice)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
            HintButton(
                configuration: HintConfiguration(
                    position: HintPosition(
                        tailParameters: TKHintTextView.tailParameters,
                        horizontal: .default,
                        vertical: .init(absolute: 1),
                        direction: .bottomLeft
                    ),
                    animationStyle: .bouncing
                )
            ) { position in
                TKHintTextView(text: TKLocales.Perps.Asset.LiquidationPrice.hint, position: position)
            } label: {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.informationCircle)
                    .renderingMode(.template)
                    .foregroundStyle(.iconSecondary)
            }
            Spacer()
            Text(viewModel.liquidationText ?? "—")
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, PerpsLeverageSheetLayout.inset)
        .padding(.vertical, PerpsLeverageSheetLayout.rowVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: PerpsLeverageSheetLayout.cornerRadius))
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
}

private enum PerpsLeverageSheetLayout {
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
