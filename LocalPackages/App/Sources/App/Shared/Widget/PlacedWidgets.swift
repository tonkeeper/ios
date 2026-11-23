import WidgetKit

enum PlacedWidgets {
    /// `launch_app.widgets`: one `<widget>:<family>` item per placed widget, duplicates kept; `nil` when the system did not answer.
    static func analyticsValue() async -> [String]? {
        let widgets = await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                continuation.resume(returning: try? result.get())
            }
        }
        return widgets.map { analyticsValue(of: $0.map { ($0.kind, $0.family) }) }
    }

    static func analyticsValue(of widgets: [(kind: String, family: WidgetFamily)]) -> [String] {
        widgets.compactMap { widget in
            guard let kind = WalletWidgetLink.Widget(kind: widget.kind),
                  let family = WalletWidgetLink.Family(widget.family)
            else { return nil }
            return "\(kind.rawValue):\(family.rawValue)"
        }
    }
}
