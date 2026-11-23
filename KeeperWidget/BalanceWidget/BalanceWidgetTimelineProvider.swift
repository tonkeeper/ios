import WidgetKit

/// The app reloads the timeline whenever the snapshot changes, so one entry is enough. The widget asks again
/// at midnight only to show the data's date.
@available(iOS 17.0, *)
struct BalanceWidgetTimelineProvider: AppIntentTimelineProvider {
    /// Only the medium balance widget lists assets.
    var loadsAssetIcons = false

    func placeholder(in context: Context) -> BalanceWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: BalanceWidgetConfigurationIntent, in context: Context) async -> BalanceWidgetEntry {
        let entry = await entry(for: configuration, family: context.family)
        return entry.wallet == nil && context.isPreview ? .placeholder : entry
    }

    func timeline(for configuration: BalanceWidgetConfigurationIntent, in context: Context) async -> Timeline<BalanceWidgetEntry> {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
        return await Timeline(entries: [entry(for: configuration, family: context.family)], policy: tomorrow.map { .after($0) } ?? .never)
    }

    private func entry(for configuration: BalanceWidgetConfigurationIntent, family: WidgetFamily) async -> BalanceWidgetEntry {
        let snapshot = WalletWidgetSnapshot.load()
        let walletId = configuration.wallet?.walletId
        let iconURLs = loadsAssetIcons && family == .systemMedium
            ? snapshot?.wallet(id: walletId)?.topAssets.compactMap(\.iconURL) ?? []
            : []
        return await BalanceWidgetEntry(
            date: Date(),
            snapshot: snapshot,
            configuredWalletId: walletId,
            icons: PriceWidgetLoader.icons(iconURLs)
        )
    }
}
