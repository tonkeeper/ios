import AppIntents
import KeeperCore
import TKLocalize
import WidgetKit

/// Keeps the period chosen in a widget configured before App Intents: the system maps the SiriKit intent's
/// parameters onto these by name. Its currency is dropped: prices follow the app's currency.
/// The titles come from the SiriKit intent's strings, already translated.
@available(iOS 17.0, *)
struct RateWidgetConfigurationIntent: WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    static let intentClassName = "RateWidgetIntent"
    static let title = LocalizedStringResource("5XYURU", defaultValue: "Rate Widget", table: "RateWidget")

    /// A widget placed before App Intents gets the default too, so it moves from TON to Auto.
    @Parameter(title: LocalizedStringResource("Token", table: "RateWidget"))
    var asset: RateWidgetAssetEntity?

    @Parameter(title: LocalizedStringResource("REhK10", defaultValue: "Period", table: "RateWidget"), default: .day)
    var period: RateWidgetPeriod
}

@available(iOS 17.0, *)
struct RateWidgetAssetEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Token", table: "RateWidget"))
    static let defaultQuery = RateWidgetAssetQuery()

    let id: String
    let symbol: String

    var displayRepresentation: DisplayRepresentation {
        if id == Self.auto.id {
            return DisplayRepresentation(
                title: LocalizedStringResource("Auto", table: "RateWidget"),
                subtitle: LocalizedStringResource("First favorite or largest balance", table: "RateWidget")
            )
        }
        return DisplayRepresentation(title: "\(symbol)")
    }

    func asset(in snapshot: PriceWidgetSnapshot) -> PriceWidgetSnapshot.Asset {
        id == Self.auto.id ? snapshot.watchlist.first ?? .ton : PriceWidgetSnapshot.Asset(id: id, symbol: symbol)
    }
}

@available(iOS 17.0, *)
extension RateWidgetAssetEntity {
    /// What a new widget starts on: the first favorite, or the wallet's largest asset, whichever it is now.
    /// The system asks for the default once, when the app is installed or updated, so a concrete asset
    /// would be the one first then.
    static let auto = RateWidgetAssetEntity(id: "auto", symbol: "")

    init(_ asset: PriceWidgetSnapshot.Asset) {
        self.init(id: asset.id, symbol: asset.symbol)
    }
}

@available(iOS 17.0, *)
struct RateWidgetAssetQuery: EntityQuery {
    /// An asset no longer among the favorites or in the wallet is looked up in the catalog.
    func entities(for identifiers: [String]) async throws -> [RateWidgetAssetEntity] {
        let choices = PriceWidgetSnapshot.load().choices
        let unknown = identifiers.filter { id in id != RateWidgetAssetEntity.auto.id && !choices.contains { $0.id == id } }
        let loader = PriceWidgetLoader()
        let items = unknown.isEmpty ? [:] : await loader.marketItems(unknown) ?? [:]
        return identifiers.map { id in
            if id == RateWidgetAssetEntity.auto.id { return .auto }
            return choices.first { $0.id == id }.map(RateWidgetAssetEntity.init)
                ?? RateWidgetAssetEntity(id: id, symbol: items[id]?.symbol ?? id)
        }
    }

    func suggestedEntities() async throws -> [RateWidgetAssetEntity] {
        [.auto] + PriceWidgetSnapshot.load().choices.map(RateWidgetAssetEntity.init)
    }

    func defaultResult() async -> RateWidgetAssetEntity? {
        .auto
    }
}

/// The cases are named as the SiriKit intent's, so a configured period carries over.
@available(iOS 17.0, *)
enum RateWidgetPeriod: String, AppEnum {
    case hour
    case day
    case week
    case month
    case halfYear
    case year

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("REhK10", defaultValue: "Period", table: "RateWidget")
    )
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .hour: DisplayRepresentation(title: LocalizedStringResource("sbHcpN", defaultValue: "Hour", table: "RateWidget")),
        .day: DisplayRepresentation(title: LocalizedStringResource("JwoMAd", defaultValue: "Day", table: "RateWidget")),
        .week: DisplayRepresentation(title: LocalizedStringResource("4XoBvx", defaultValue: "Week", table: "RateWidget")),
        .month: DisplayRepresentation(title: LocalizedStringResource("iAVJqs", defaultValue: "Month", table: "RateWidget")),
        .halfYear: DisplayRepresentation(title: LocalizedStringResource("WDMmFN", defaultValue: "6 Months", table: "RateWidget")),
        .year: DisplayRepresentation(title: LocalizedStringResource("VIg0Yc", defaultValue: "Year", table: "RateWidget")),
    ]

    /// Like `24h`, next to the change over the period.
    var label: String {
        switch self {
        case .hour: TKLocales.Widget.Period.hour
        case .day: TKLocales.Widget.Period.day
        case .week: TKLocales.Widget.Period.week
        case .month: TKLocales.Widget.Period.month
        case .halfYear: TKLocales.Widget.Period.halfYear
        case .year: TKLocales.Widget.Period.year
        }
    }

    var period: KeeperCore.Period {
        switch self {
        case .hour: .hour
        case .day: .day
        case .week: .week
        case .month: .month
        case .halfYear: .halfYear
        case .year: .year
        }
    }
}
