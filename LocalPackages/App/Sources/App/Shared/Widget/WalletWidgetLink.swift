import Foundation
import WidgetKit

/// The URL a widget opens the app with. The app takes it before the deep link parser, like a Live
/// Activity's, so a widget tap never reaches the attribution SDKs.
struct WalletWidgetLink: Equatable {
    /// Raw values are the analytics names of the widget, its size and the tapped action.
    enum Widget: String, CaseIterable {
        case balance
        case actions
        case rate
        case rateChart = "rate_chart"
        case watchlist
        case perps
    }

    enum Family: String {
        case systemSmall = "system_small"
        case systemMedium = "system_medium"
        case systemLarge = "system_large"
        case accessoryCircular = "accessory_circular"
        case accessoryRectangular = "accessory_rectangular"
        case accessoryInline = "accessory_inline"
    }

    enum Action: String, Codable, CaseIterable {
        case open
        case send
        case buy
        case swap
        case stake
    }

    private static let scheme = "tonkeeper"
    private static let host = "widget"

    let widget: Widget
    let family: Family
    let action: Action
    /// `nil` for a widget that follows the active wallet.
    let walletId: String?
    /// The trading catalog id of the asset whose page the tap opens.
    let assetId: String?

    init(widget: Widget, family: Family, action: Action, walletId: String?, assetId: String? = nil) {
        self.widget = widget
        self.family = family
        self.action = action
        self.walletId = walletId
        self.assetId = assetId
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host == Self.host,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let widget = items.value("widget").flatMap(Widget.init(rawValue:)),
              let family = items.value("family").flatMap(Family.init(rawValue:))
        else {
            return nil
        }
        self.init(
            widget: widget,
            family: family,
            action: items.value("action").flatMap(Action.init(rawValue:)) ?? .open,
            walletId: items.value("wallet_id"),
            assetId: items.value("asset_id")
        )
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [
            URLQueryItem(name: "widget", value: widget.rawValue),
            URLQueryItem(name: "family", value: family.rawValue),
            URLQueryItem(name: "action", value: action.rawValue),
        ]
        if let walletId {
            components.queryItems?.append(URLQueryItem(name: "wallet_id", value: walletId))
        }
        if let assetId {
            components.queryItems?.append(URLQueryItem(name: "asset_id", value: assetId))
        }
        // The flow a tap opens reports these on its events, as a deep link would.
        components.queryItems? += [
            URLQueryItem(name: "utm_source", value: "tonkeeper"),
            URLQueryItem(name: "utm_medium", value: "widget"),
            URLQueryItem(name: "utm_content", value: "\(widget.rawValue)_\(family.rawValue)"),
        ]
        return components.url
    }
}

private extension [URLQueryItem] {
    func value(_ name: String) -> String? {
        first { $0.name == name }?.value
    }
}

extension WalletWidgetLink.Widget {
    /// The widgets that load prices in the app's currency.
    static let priceKinds: [Self] = [.rate, .rateChart, .watchlist]
    /// The widgets that show a wallet from the snapshot.
    static let walletKinds: [Self] = [.balance, .actions]

    var kind: String {
        switch self {
        case .balance: "BalanceWidget"
        case .actions: "ActionsWidget"
        case .rate: "RateWidget"
        case .rateChart: "RateChartWidget"
        case .watchlist: "WatchlistWidget"
        case .perps: "PerpsWidget"
        }
    }

    init?(kind: String) {
        guard let widget = Self.allCases.first(where: { $0.kind == kind }) else { return nil }
        self = widget
    }
}

extension WalletWidgetLink.Family {
    init?(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .systemSmall
        case .systemMedium: self = .systemMedium
        case .systemLarge: self = .systemLarge
        case .accessoryCircular: self = .accessoryCircular
        case .accessoryRectangular: self = .accessoryRectangular
        case .accessoryInline: self = .accessoryInline
        default: return nil
        }
    }
}
