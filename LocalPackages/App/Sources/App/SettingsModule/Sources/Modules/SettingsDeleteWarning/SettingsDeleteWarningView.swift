import SwiftUI
import TKLocalize
import TKUIKit

struct SettingsDeleteWarningView: View {
    let title: String
    let caption: String
    let buttonTitle: String
    let walletIcon: SwiftUI.Image?
    let walletName: String
    let onSignOut: () -> Void
    let onBackup: () -> Void

    @Environment(\.tkPalette) private var palette
    @State private var isConfirmed = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Layout.titleSpacing) {
                Text(title)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                Text(caption)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Layout.titleHorizontalInset)
            .padding(.bottom, Layout.captionBottomInset)

            confirmationCard
                .padding(.bottom, Layout.cardBottomInset)

            ButtonView(
                config: .init(
                    title: buttonTitle,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .secondary,
                    action: onSignOut
                )
            )
            .disabled(!isConfirmed)
            .padding(.bottom, Layout.bottomInset)
        }
        .padding(.horizontal, Layout.horizontalInset)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var tickTextView: Text {
        if let walletIcon {
            [
                Text(walletIcon.renderingMode(.template))
                    .baselineOffset(-2)
                    .foregroundColor(palette.icon.primary),
                Text(" \(walletName)"),
            ].reduce(Text(TKLocales.SignOutWarning.tickDescription), +)
        } else {
            Text(TKLocales.SignOutWarning.tickDescription) + Text("\(walletName)")
        }
    }

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
            Button {
                isConfirmed.toggle()
            } label: {
                HStack(alignment: .top, spacing: Layout.tickTextSpacing) {
                    CheckboxView(isSelected: isConfirmed)

                    tickTextView
                        .textStyle(.body1)
                        .foregroundStyle(.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
            .buttonStyle(TKTapAnimationButtonStyle())

            Button(action: onBackup) {
                Text(TKLocales.SignOutWarning.tickBackUp)
                    .textStyle(.label1)
                    .foregroundStyle(.accentBlue)
            }
            .buttonStyle(TKTapAnimationButtonStyle())
            .padding(.leading, Layout.backupButtonLeadingInset)
            .padding(.bottom, Layout.backupButtonBottomInset)
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.backgroundContent)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Layout.cardCornerRadius,
                style: .continuous
            )
        )
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let titleSpacing: CGFloat = 4
        static let titleHorizontalInset: CGFloat = 16
        static let captionBottomInset: CGFloat = 32
        static let cardPadding: CGFloat = 16
        static let cardCornerRadius: CGFloat = 16
        static let cardContentSpacing: CGFloat = 6
        static let tickTextSpacing: CGFloat = 12
        static let backupButtonLeadingInset: CGFloat = 40
        static let backupButtonBottomInset: CGFloat = 1
        static let cardBottomInset: CGFloat = 32
        static let bottomInset: CGFloat = 3
    }
}
