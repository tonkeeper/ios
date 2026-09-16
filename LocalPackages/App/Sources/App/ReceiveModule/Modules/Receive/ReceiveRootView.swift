import SwiftUI
import TKUIKit

struct ReceiveRootView: View {
    @ObservedObject var viewModel: ReceiveViewModelImplementation

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            VStack(spacing: 0) {
                ReceiveTitleBlockView(network: viewModel.selectedNetwork)

                ReceiveQRCardView(
                    matrix: viewModel.qrCodeMatrix,
                    network: viewModel.selectedNetwork,
                    onCopy: viewModel.copyAddress
                )
                .padding(.top, Layout.cardTopPadding)
                .padding(.horizontal, Layout.cardHorizontalPadding)

                ReceiveActionRowView(
                    onCopy: viewModel.copyAddress,
                    onShare: viewModel.shareSelectedAddress
                )
                .padding(.top, Layout.actionsTopPadding)
                .padding(.bottom, Layout.actionsBottomPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.clear)
    }
}

extension ReceiveRootView {
    enum Layout {
        static let actionsBottomPadding: CGFloat = 8
        static let actionsTopPadding: CGFloat = 16
        static let cardHorizontalPadding: CGFloat = 47
        static let cardTopPadding: CGFloat = 34
        static let titleHorizontalPadding: CGFloat = 32
    }
}
