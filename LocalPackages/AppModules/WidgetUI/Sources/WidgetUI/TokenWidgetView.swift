import SwiftUI
import TKUIKit
import WidgetKit

public struct TokenWidgetState {
    public let symbol: String
    public let icon: UIImage?
    /// `nil` while the catalog cannot be reached and nothing was loaded before.
    public let price: String?
    /// Over `period`, in percent.
    public let change: WidgetChange?
    /// Over `period`, in fiat: the Lock Screen has no room for the percent.
    public let fiatChange: WidgetChange?
    public let period: String
    /// `nil` while the shown data is a cached copy.
    public let updatedAt: Date?
    /// The prices over `period`, oldest first.
    public let chart: [Double]

    public init(
        symbol: String,
        icon: UIImage?,
        price: String?,
        change: WidgetChange?,
        fiatChange: WidgetChange?,
        period: String,
        updatedAt: Date?,
        chart: [Double]
    ) {
        self.symbol = symbol
        self.icon = icon
        self.price = price
        self.change = change
        self.fiatChange = fiatChange
        self.period = period
        self.updatedAt = updatedAt
        self.chart = chart
    }

    var priceText: String {
        price ?? "—"
    }

    var isDown: Bool? {
        (change ?? fiatChange)?.isDown
    }
}

/// The price widget: a large price on the Home Screen, the price with its change on the Lock Screen.
@available(iOS 17.0, *)
public struct TokenWidgetView: View {
    let state: TokenWidgetState
    let family: WidgetFamily

    public init(state: TokenWidgetState, family: WidgetFamily) {
        self.state = state
        self.family = family
    }

    public var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                TokenWidgetLockHeader(state: state)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(state.priceText)
                        .textStyle(.h2)
                        .widgetAccentable()
                    if let fiatChange = state.fiatChange {
                        Text(fiatChange.text)
                            .textStyle(.label2)
                    }
                }
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(AccessoryWidgetBackground())
        case .accessoryCircular:
            VStack(spacing: 0) {
                TokenWidgetTrendIcon(isDown: state.isDown)
                Text(state.symbol)
                Text(state.priceText)
                    .widgetAccentable()
            }
            .textStyle(.label2)
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AccessoryWidgetBackground())
        default:
            VStack(alignment: .leading, spacing: 0) {
                TokenWidgetHeader(state: state)
                if let updatedAt = state.updatedAt {
                    WidgetUpdatedText(date: updatedAt)
                        .padding(.top, 6)
                }
                Spacer(minLength: 8)
                Text(state.priceText)
                    .textStyle(.num1)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let change = state.change {
                    WidgetChangeText(change: change, period: state.period, style: .body2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// The price chart widget: the line across the whole widget, the price under it.
@available(iOS 17.0, *)
public struct TokenChartWidgetView: View {
    let state: TokenWidgetState
    let family: WidgetFamily

    public init(state: TokenWidgetState, family: WidgetFamily) {
        self.state = state
        self.family = family
    }

    public var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    TokenWidgetLockHeader(state: state)
                    Spacer(minLength: 4)
                    Text(state.priceText)
                        .textStyle(.label2)
                        .lineLimit(1)
                        .widgetAccentable()
                }
                WidgetChartView(values: state.chart, lineWidth: 2, tint: .primary)
                    .frame(height: 24)
            }
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(AccessoryWidgetBackground())
        default:
            let isMedium = family == .systemMedium
            VStack(alignment: .leading, spacing: 0) {
                TokenWidgetHeader(state: state)
                    .padding([.horizontal, .top], 16)
                Spacer(minLength: 0)
                WidgetChartView(values: state.chart, lineWidth: 2.5, fills: true, isDown: state.isDown)
                    .frame(height: isMedium ? 56 : 48)
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(state.priceText)
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if let change = state.change {
                            WidgetChangeText(change: change, period: state.period, style: .body2)
                        }
                    }
                    if isMedium, let updatedAt = state.updatedAt {
                        Spacer(minLength: 8)
                        WidgetUpdatedText(date: updatedAt)
                            .padding(.bottom, 2)
                    }
                }
                .padding([.horizontal, .bottom], 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

@available(iOS 17.0, *)
private struct TokenWidgetHeader: View {
    let state: TokenWidgetState

    var body: some View {
        HStack(spacing: 8) {
            WidgetTokenIcon(symbol: state.symbol, image: state.icon, size: 20)
            Text(state.symbol)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            WidgetLogoView()
        }
    }
}

@available(iOS 17.0, *)
private struct TokenWidgetLockHeader: View {
    let state: TokenWidgetState

    var body: some View {
        HStack(spacing: 4) {
            TokenWidgetTrendIcon(isDown: state.isDown)
            Text(state.symbol)
                .textStyle(.label2)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }
}

@available(iOS 17.0, *)
private struct TokenWidgetTrendIcon: View {
    /// `nil` without a change: no arrow, so a missing change does not read as a rise.
    let isDown: Bool?

    var body: some View {
        if let isDown {
            Image(systemName: isDown ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                .font(.system(size: 8))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
        }
    }
}
