import SwiftUI
import WidgetKit

struct RateWidget: Widget {
    let kind: String = "RateWidget"

    var supportedFamilies: [WidgetFamily] {
        return [.systemSmall]
    }

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: RateWidgetIntent.self,
            provider: RateWidgetTimelineProvider()
        ) { entry in
            RateWidgetView(entry: entry)
                .widgetBackground(backgroundView: Color(UIColor.Background.page))
        }
        .configurationDisplayName("Rate")
        .description("")
        .supportedFamilies(supportedFamilies)
        .contentMarginsDisabledIfAvailable()
    }
}
