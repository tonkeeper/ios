import SwiftUI
import WidgetKit

struct BalanceWidget: Widget {
    let kind = "BalanceWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: BalanceWidgetIntent.self,
            provider: BalanceWidgetTimelineProvider()
        ) { entry in
            BalanceWidgetView(entry: entry)
                .widgetBackground(backgroundView: Color(UIColor.Background.page))
        }
        .configurationDisplayName("Wallet balance")
        .description("")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabledIfAvailable()
    }
}
