import SwiftUI
import TKUIKit
import UIKit

struct WalletConnectProposalLogosView: View {
    let walletAddress: String
    let dappIconURL: URL?
    let validationBadge: WalletConnectProposalValidationBadge?

    var body: some View {
        ZStack {
            HStack(spacing: Layout.logoSpacing) {
                WalletConnectProposalLogoView(
                    image: BrandMarks.AppIcon.image
                )
                WalletConnectProposalRemoteLogoView(
                    url: dappIconURL
                )
                .overlay(alignment: .bottomTrailing) {
                    if let validationBadge {
                        WalletConnectProposalValidationBadgeView(badge: validationBadge)
                            .offset(x: Layout.badgeOffset, y: Layout.badgeOffset)
                    }
                }
            }

            addressBridge
        }
        .frame(height: Layout.logoSize)
    }
}

private extension WalletConnectProposalLogosView {
    var addressBridge: some View {
        HStack(spacing: 0) {
            WalletConnectProposalTickerText(
                text: walletAddress,
                fade: .leading,
                width: Layout.bridgeSideWidth
            )

            Rectangle()
                .fill(.separatorCommon)
                .frame(
                    width: Layout.bridgeSeparatorWidth,
                    height: Layout.bridgeSeparatorHeight
                )

            WalletConnectProposalTickerText(
                text: maskedAddress,
                fade: .trailing,
                width: Layout.bridgeSideWidth
            )
            .offset(y: Layout.maskedAddressBaselineOffset)
        }
        .frame(width: Layout.bridgeWidth, height: Layout.logoSize)
    }

    /// Thin spaces keep the asterisks from reading as a solid rule, and one per address character keeps
    /// the masked side as long as the address it stands in for.
    var maskedAddress: String {
        String(repeating: "*\u{2009}", count: walletAddress.count)
    }

    enum Layout {
        static let logoSize: CGFloat = 72
        static let logoSpacing: CGFloat = 86
        static let bridgeWidth: CGFloat = 86
        static let bridgeSideWidth: CGFloat = 42.5
        static let bridgeSeparatorWidth: CGFloat = 1
        static let bridgeSeparatorHeight: CGFloat = 32
        static let badgeOffset: CGFloat = 6
        /// Asterisks sit high in the line box, so they need nudging down to sit on the address's line.
        static let maskedAddressBaselineOffset: CGFloat = 3
    }
}
