import SwiftUI
import TKUIKit
import UIKit

struct WalletConnectProposalValidationBadge {
    let icon: UIImage
    let tintColor: TKColor
}

struct WalletConnectProposalValidationBadgeView: View {
    let badge: WalletConnectProposalValidationBadge

    var body: some View {
        ZStack {
            Circle()
                .fill(.backgroundPage)

            Circle()
                .fill(badge.tintColor)
                .frame(width: Layout.badgeSize, height: Layout.badgeSize)

            SwiftUI.Image(uiImage: badge.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.constantWhite)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
        }
        .frame(width: Layout.containerSize, height: Layout.containerSize)
    }

    enum Layout {
        static let containerSize: CGFloat = 28
        static let badgeSize: CGFloat = 24
        static let iconSize: CGFloat = 16
    }
}
