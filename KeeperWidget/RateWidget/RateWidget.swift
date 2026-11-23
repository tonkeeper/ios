import SwiftUI
import TKLocalize
import WidgetKit

@available(iOS 17.0, *)
struct RateWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WalletWidgetLink.Widget.rate.kind,
            intent: RateWidgetConfigurationIntent.self,
            provider: RateWidgetTimelineProvider()
        ) { entry in
            RateWidgetEntryView(entry: entry, widget: .rate)
        }
        .configurationDisplayName(TKLocales.Widget.Rate.title)
        .description(TKLocales.Widget.Rate.description)
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }
}
