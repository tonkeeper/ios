import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Risk disclosure", traits: .sizeThatFitsLayout) {
    PerpsRiskDisclosureSheetView(keeperTermsURL: URL(string: "https://tonkeeper.com/terms"))
        .frame(width: 390)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Risk disclosure, narrow", traits: .sizeThatFitsLayout) {
    PerpsRiskDisclosureSheetView(keeperTermsURL: URL(string: "https://tonkeeper.com/terms"))
        .frame(width: 320)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}
