import SwiftUI
import TKLocalize

struct UnverifiedTokenInfoPopupView: View {
    let dismiss: () -> Void

    var body: some View {
        BulletsInfoPopupView(
            content: BulletsInfoPopupContent(
                title: TKLocales.Token.unverified,
                caption: TKLocales.Token.UnverifiedPopup.caption,
                captionStyle: .body2,
                bullets: [
                    TKLocales.Token.UnverifiedPopup.lowLiquidity,
                    TKLocales.Token.UnverifiedPopup.notListed,
                    TKLocales.Token.UnverifiedPopup.usedForSpam,
                    TKLocales.Token.UnverifiedPopup.usedForScam,
                ]
            ),
            onPrimaryTap: dismiss
        )
    }
}
