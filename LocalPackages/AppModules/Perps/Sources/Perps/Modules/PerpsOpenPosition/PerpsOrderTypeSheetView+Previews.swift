import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Order type", traits: .sizeThatFitsLayout) {
    PerpsOrderTypeSheetView(viewModel: PerpsOrderTypeSheetViewModel(selected: .limit))
        .frame(width: 390)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}
