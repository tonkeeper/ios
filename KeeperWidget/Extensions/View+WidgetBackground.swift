import SwiftUI
import WidgetKit

extension View {
    #if swift(>=5.9)
        func widgetBackground(backgroundView: some View) -> some View {
            if #available(iOSApplicationExtension 17.0, *) {
                return containerBackground(for: .widget) {
                    backgroundView
                }
            } else {
                return background(backgroundView)
            }
        }
    #else
        func widgetBackground(backgroundView: some View) -> some View {
            return background(backgroundView)
        }
    #endif
}
