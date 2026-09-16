import SwiftUI
import TKUIKit
import UIKit

struct WalletConnectProposalLogoView: View {
    let image: UIImage

    var body: some View {
        SwiftUI.Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(
                width: Layout.size,
                height: Layout.size
            )
            .background(.backgroundContent)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Layout.cornerRadius,
                    style: .continuous
                )
            )
    }

    enum Layout {
        static let size: CGFloat = 72
        static let cornerRadius: CGFloat = 20
    }
}
