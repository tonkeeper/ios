import SwiftUI
import TKLocalize
import TKUIKit
import WidgetKit

public struct BalanceWidgetState {
    public struct Asset: Identifiable {
        public let id: String
        public let symbol: String
        /// `nil` while amounts are hidden.
        public let amount: String?
        public let icon: UIImage?

        public init(id: String, symbol: String, amount: String?, icon: UIImage?) {
            self.id = id
            self.symbol = symbol
            self.amount = amount
            self.icon = icon
        }
    }

    public let wallet: WidgetWallet
    /// `nil` while it is unknown or while amounts are hidden.
    public let total: String?
    /// Like `$8.2K`, for the circular widget.
    public let totalCompact: String?
    public let decimalSeparator: String
    /// Over 24 hours.
    public let change: WidgetChange?
    public let assets: [Asset]
    public let updatedAt: Date?
    public let hidesAmounts: Bool

    public init(
        wallet: WidgetWallet,
        total: String?,
        totalCompact: String?,
        decimalSeparator: String,
        change: WidgetChange?,
        assets: [Asset],
        updatedAt: Date?,
        hidesAmounts: Bool
    ) {
        self.wallet = wallet
        self.total = total
        self.totalCompact = totalCompact
        self.decimalSeparator = decimalSeparator
        self.change = change
        self.assets = assets
        self.updatedAt = updatedAt
        self.hidesAmounts = hidesAmounts
    }

    var totalText: String {
        hidesAmounts ? WidgetTheme.hiddenAmount : total ?? "—"
    }

    var totalCompactText: String {
        hidesAmounts ? WidgetTheme.hiddenAmount : totalCompact ?? "—"
    }
}

@available(iOS 17.0, *)
public struct BalanceWidgetView: View {
    let state: BalanceWidgetState
    let family: WidgetFamily

    public init(state: BalanceWidgetState, family: WidgetFamily) {
        self.state = state
        self.family = family
    }

    public var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        case .accessoryCircular:
            circular
        case .accessoryInline:
            Text("\(state.wallet.emoji.map { "\($0) " } ?? "")\(state.totalText)")
                .privacySensitive()
        default:
            home
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                WidgetWalletView(wallet: state.wallet)
                Spacer(minLength: 0)
                WidgetLogoView()
            }
            if let updatedAt = state.updatedAt {
                WidgetUpdatedText(date: updatedAt)
                    .padding(.top, 4)
            }
            Spacer(minLength: 8)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetAmountText(text: state.totalText, decimalSeparator: state.decimalSeparator, style: .h2, fractionStyle: .h3)
                    if let change = state.change {
                        WidgetChangeText(change: change, period: TKLocales.Widget.Period.day, style: .body2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if family == .systemMedium, !state.assets.isEmpty {
                    assets.frame(width: 168)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var assets: some View {
        VStack(spacing: 10) {
            ForEach(state.assets.prefix(3)) { asset in
                HStack(spacing: 8) {
                    WidgetTokenIcon(symbol: asset.symbol, image: asset.icon, size: 20)
                    Text(asset.symbol)
                        .textStyle(.label2)
                        .foregroundStyle(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(asset.amount ?? WidgetTheme.hiddenAmount)
                        .textStyle(.label2)
                        .foregroundStyle(.textSecondary)
                        .privacySensitive()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetWalletView(wallet: state.wallet)
            WidgetAmountText(text: state.totalText, decimalSeparator: state.decimalSeparator, style: .h2, fractionStyle: .h3)
                .widgetAccentable()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AccessoryWidgetBackground())
    }

    private var circular: some View {
        VStack(spacing: 0) {
            Text(state.wallet.name)
            Text(state.totalCompactText)
                .privacySensitive()
                .widgetAccentable()
        }
        .textStyle(.label2)
        .foregroundStyle(.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AccessoryWidgetBackground())
    }
}
