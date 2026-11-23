import SwiftUI
import TKLocalize
import TKUIKit
import WidgetKit

public struct TokenListWidgetState {
    public struct Row: Identifiable {
        public let id: String
        public let symbol: String
        public let name: String?
        public let icon: UIImage?
        public let price: String?
        public let change: WidgetChange?
        /// The prices over the list's period, oldest first.
        public let chart: [Double]
        /// The token's page.
        public let url: URL?

        public init(id: String, symbol: String, name: String?, icon: UIImage?, price: String?, change: WidgetChange?, chart: [Double], url: URL?) {
            self.id = id
            self.symbol = symbol
            self.name = name
            self.icon = icon
            self.price = price
            self.change = change
            self.chart = chart
            self.url = url
        }
    }

    public let rows: [Row]
    public let period: String
    /// `nil` while the shown data is a cached copy.
    public let updatedAt: Date?

    public init(rows: [Row], period: String, updatedAt: Date?) {
        self.rows = rows
        self.period = period
        self.updatedAt = updatedAt
    }

    public static func rows(in family: WidgetFamily) -> Int {
        family == .systemLarge ? 5 : 2
    }
}

/// Every slot is laid out, so rows keep their place when there are fewer tokens than slots.
@available(iOS 17.0, *)
public struct TokenListWidgetView: View {
    let state: TokenListWidgetState
    let family: WidgetFamily

    public init(state: TokenListWidgetState, family: WidgetFamily) {
        self.state = state
        self.family = family
    }

    public var body: some View {
        let slots = TokenListWidgetState.rows(in: family)
        VStack(spacing: 0) {
            header
                .padding(.bottom, 12)
            ForEach(0 ..< slots, id: \.self) { index in
                if index > 0 {
                    Spacer(minLength: 0)
                }
                Group {
                    if index < state.rows.count {
                        row(state.rows[index])
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 40)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(TKLocales.Widget.Watchlist.header)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
            Text(state.period)
                .textStyle(.body3)
                .foregroundStyle(.textSecondary)
                .padding(.top, 4)
            Spacer(minLength: 0)
            if let updatedAt = state.updatedAt {
                WidgetUpdatedText(date: updatedAt)
            }
            WidgetLogoView()
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private func row(_ row: TokenListWidgetState.Row) -> some View {
        if let url = row.url {
            Link(destination: url) { TokenListWidgetRow(row: row) }
        } else {
            TokenListWidgetRow(row: row)
        }
    }
}

@available(iOS 17.0, *)
private struct TokenListWidgetRow: View {
    let row: TokenListWidgetState.Row

    var body: some View {
        HStack(spacing: 12) {
            WidgetTokenIcon(symbol: row.symbol, image: row.icon, size: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.symbol)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                if let name = row.name {
                    Text(name)
                        .textStyle(.body3)
                        .foregroundStyle(.textSecondary)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            WidgetChartView(values: row.chart, lineWidth: 1.75, isDown: row.change?.isDown)
                .frame(width: 64, height: 24)
            VStack(alignment: .trailing, spacing: 0) {
                Text(row.price ?? "—")
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                if let change = row.change {
                    WidgetChangeText(change: change, period: nil, style: .body3)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 96, alignment: .trailing)
        }
    }
}
