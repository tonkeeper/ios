import SwiftUI
import TKLocalize
import TKUIKit

struct SupportPopupView: View {
    let onAsk: () -> Void
    let onEmail: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.messageBubble)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.accentBlue)
                .frame(height: Layout.iconHeight)
                .padding(.bottom, Layout.iconBottomInset)

            VStack(spacing: Layout.titleSpacing) {
                Text(TKLocales.Support.SupportPopup.title)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                Text(TKLocales.Support.SupportPopup.caption)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Layout.titleHorizontalInset)
            .padding(.bottom, Layout.titleBottomInset)

            VStack(spacing: Layout.buttonSpacing) {
                ButtonView(
                    config: .init(
                        title: TKLocales.Support.SupportPopup.Buttons.ask,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .primary,
                        icon: ButtonView.Icon(image: .TKUIKit.Icons.Size16.telegram),
                        action: onAsk
                    )
                )

                ButtonView(
                    config: .init(
                        title: TKLocales.Support.SupportPopup.Buttons.email,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .secondary,
                        icon: ButtonView.Icon(image: .TKUIKit.Icons.Size16.envelope),
                        action: onEmail
                    )
                )
            }
            .padding([.top, .leading, .trailing], Layout.buttonInset)
            .padding(.bottom, Layout.bottomInset)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
        .ignoresSafeArea(.container, edges: .top)
    }
}

private extension SupportPopupView {
    enum Layout {
        static let iconHeight: CGFloat = 84
        static let iconBottomInset: CGFloat = 13
        static let titleSpacing: CGFloat = 3
        static let titleHorizontalInset: CGFloat = 32
        static let titleBottomInset: CGFloat = 16
        static let buttonSpacing: CGFloat = 16
        static let buttonInset: CGFloat = 16
        static let bottomInset: CGFloat = 3
    }
}
