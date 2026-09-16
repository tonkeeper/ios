import SwiftUI
import TKLocalize

struct TonCollectiblesInfoPopupView: View {
    let dismiss: () -> Void

    var body: some View {
        BulletsInfoPopupView(
            content: BulletsInfoPopupContent(
                title: TKLocales.Collectibles.TonCollectiblesPopup.title,
                caption: TKLocales.Collectibles.TonCollectiblesPopup.caption,
                captionStyle: .body2,
                bullets: []
            ),
            onPrimaryTap: dismiss
        )
    }
}
