import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Edit position", traits: .sizeThatFitsLayout) {
    PerpsEditPositionSheetView(side: .long, onAdd: {}, onReduce: {})
        .frame(width: 390)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}
