import SwiftUI

@available(iOS 17.0, *)
#Preview("States", traits: .sizeThatFitsLayout) {
    VStack(spacing: 0) {
        TKActionBar(successTitle: "Done", failureTitle: "Error") {
            ButtonView(config: ButtonView.Config(title: "Confirm", size: .large, layoutMode: .fill, appearance: .primary) {})
        }
        TKActionBar(process: .processing, successTitle: "Done", failureTitle: "Error") {
            EmptyView()
        }
        TKActionBar(process: .success, successTitle: "Done", failureTitle: "Error") {
            EmptyView()
        }
        TKActionBar(process: .failure, successTitle: "Done", failureTitle: "Error") {
            EmptyView()
        }
    }
    .frame(width: 390)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}
