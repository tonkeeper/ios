import SwiftUI
import TKLocalize
import TKUIKit

/// The sheet's list of payment methods; the sheet header gives its title and close button.
/// Methods with an `otherToken` are folded into one Other tokens row.
public struct BatteryPayWithView: View {
    private let methods: [BatteryRefillViewState.PaymentMethod]
    private let otherTokens: [BatteryRefillViewState.PaymentMethod]
    private let onSelect: (String) -> Void
    private let onOtherTokens: () -> Void

    public init(
        methods: [BatteryRefillViewState.PaymentMethod],
        onSelect: @escaping (String) -> Void,
        onOtherTokens: @escaping () -> Void = {}
    ) {
        self.methods = methods.filter { $0.otherToken == nil }
        self.otherTokens = methods.filter { $0.otherToken != nil }
        self.onSelect = onSelect
        self.onOtherTokens = onOtherTokens
    }

    public var body: some View {
        VStack(spacing: Layout.groupSpacing) {
            if !methods.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(methods.enumerated()), id: \.element.id) { index, method in
                        BatteryPaymentMethodCell(
                            method: method,
                            title: method.name,
                            trailing: method.isSelected ? .checkmark : .none,
                            showsDivider: index < methods.count - 1,
                            action: { onSelect(method.id) }
                        )
                        .accessibilityIdentifier("battery_pay_with_\(method.id)")
                    }
                }
                .asCellsGroup()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("battery_pay_with_list")
            }
            if !otherTokens.isEmpty {
                otherTokensRow
                    .asCellsGroup()
            }
        }
        .padding(.bottom, Layout.bottomPadding)
    }

    private var otherTokensRow: some View {
        Cell(
            config: Cell.Config(action: onOtherTokens),
            center: {
                CellCenter {
                    Text(TKLocales.Battery.Refill.OtherTokens.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                } secondaryRow: {
                    Text(Self.otherTokensCaption(symbols: otherTokens.map(\.name)))
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            },
            trailing: {
                BatteryChevronAccessory()
            }
        )
        .accessibilityIdentifier("battery_pay_with_other_tokens")
    }

    /// The first symbols, then how many more there are; a token on several chains counts once.
    public static func otherTokensCaption(symbols: [String], shown: Int = 3) -> String {
        var unique: [String] = []
        for symbol in symbols where !unique.contains(symbol) {
            unique.append(symbol)
        }
        let listed = unique.prefix(shown).joined(separator: ", ")
        let more = unique.count - shown
        return more > 0 ? TKLocales.Battery.Refill.OtherTokens.caption(listed, more) : listed
    }

    private enum Layout {
        static let groupSpacing: CGFloat = 16
        static let bottomPadding: CGFloat = 16
    }
}
