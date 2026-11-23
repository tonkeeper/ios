import SwiftUI
import TKLocalize
import WidgetKit

@available(iOS 17.0, *)
struct RateChartWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WalletWidgetLink.Widget.rateChart.kind,
            intent: RateWidgetConfigurationIntent.self,
            provider: RateWidgetTimelineProvider()
        ) { entry in
            RateWidgetEntryView(entry: entry, widget: .rateChart)
        }
        .configurationDisplayName(TKLocales.Widget.RateChart.title)
        .description(TKLocales.Widget.RateChart.description)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
