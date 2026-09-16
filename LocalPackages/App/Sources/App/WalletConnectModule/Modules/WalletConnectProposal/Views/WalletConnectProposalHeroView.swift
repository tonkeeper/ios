import SwiftUI
import TKLocalize
import TKUIKit

struct WalletConnectProposalHeroView: View {
    let content: WalletConnectProposalContent
    let onDAppHostTap: () -> Void
    @Environment(\.tkPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            WalletConnectProposalLogosView(
                walletAddress: content.walletAddress,
                dappIconURL: content.dappIconURL,
                validationBadge: content.validation.proposalBadge
            )
            .padding(.bottom, Layout.logosBottomPadding)

            VStack(spacing: Layout.textSpacing) {
                Text(title)
                    .textStyle(.h2)
                    .tint(content.validation.proposalTitleAccentColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.openURL, OpenURLAction { _ in
                        onDAppHostTap()
                        return .handled
                    })

                Text(TKLocales.WalletConnect.Proposal.requestingAccess(content.dappName))
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Layout.textHorizontalPadding)
            .padding(.bottom, Layout.textBottomPadding)
        }
    }
}

private extension WalletConnectProposalHeroView {
    var title: AttributedString {
        var text = AttributedString(TKLocales.WalletConnect.Proposal.connectTo(content.dappHost))
        text.foregroundColor = palette.text.primary
        if let range = text.range(of: content.dappHost) {
            text[range].foregroundColor = content.validation.proposalTitleAccentColor.resolve(palette)
            text[range].link = content.dappURL
        }
        return text
    }

    enum Layout {
        static let logosBottomPadding: CGFloat = 21
        static let textSpacing: CGFloat = 3
        static let textHorizontalPadding: CGFloat = 32
        static let textBottomPadding: CGFloat = 24
    }
}
