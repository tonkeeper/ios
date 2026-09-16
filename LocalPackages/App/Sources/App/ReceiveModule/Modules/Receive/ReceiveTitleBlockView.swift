import SwiftUI
import TKUIKit

struct ReceiveTitleBlockView: View {
    let network: ReceiveNetworkViewData

    var body: some View {
        VStack(spacing: 4) {
            Text(network.addressTitle)
                .textStyle(.h3)
                .foregroundStyle(.textPrimary)

            Text(network.disclaimer)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 1)
        }
        .padding(.horizontal, ReceiveRootView.Layout.titleHorizontalPadding)
    }
}
