import SwiftUI
import TKLocalize

struct WalletMigrationInfoPopupView: View {
    let dismiss: () -> Void

    var body: some View {
        BulletsInfoPopupView(
            content: BulletsInfoPopupContent(
                title: TKLocales.Settings.Migration.Info.title,
                caption: TKLocales.Settings.Migration.Info.caption,
                captionStyle: .body2,
                bullets: [
                    TKLocales.Settings.Migration.Info.willMigrate,
                    TKLocales.Settings.Migration.Info.willStay,
                    TKLocales.Settings.Migration.Info.note,
                ]
            ),
            onPrimaryTap: dismiss
        )
    }
}
