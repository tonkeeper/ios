import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Adjust margin", traits: .sizeThatFitsLayout) {
    PerpsAdjustMarginSheetView(onAdd: {}, onReduce: {})
        .frame(width: 390)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}
