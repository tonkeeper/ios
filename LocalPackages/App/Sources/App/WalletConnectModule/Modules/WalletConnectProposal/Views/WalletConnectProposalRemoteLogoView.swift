import Kingfisher
import SwiftUI
import TKUIKit

struct WalletConnectProposalRemoteLogoView: View {
    let url: URL?

    @State private var didFail = false

    var body: some View {
        Group {
            if let url, !didFail {
                let iconSource = DappIconSource(url: url)
                KFImage
                    .source(iconSource.source)
                    .alternativeSources(iconSource.alternativeSources)
                    .placeholder {
                        ShimmerSwiftUIView(
                            config: ShimmerSwiftUIView.Config(
                                color: .backgroundContentTint,
                                cornerRadius: .value(WalletConnectProposalLogoView.Layout.cornerRadius)
                            )
                        )
                    }
                    .onSuccess { _ in didFail = false }
                    .onFailure { _ in didFail = true }
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFill()
            } else {
                SwiftUI.Image.TKUIKit.Icons.Size44.placeholder
                    .resizable()
                    .scaledToFit()
                    .padding(14)
            }
        }
        .frame(
            width: WalletConnectProposalLogoView.Layout.size,
            height: WalletConnectProposalLogoView.Layout.size
        )
        .background(.backgroundContent)
        .clipShape(
            RoundedRectangle(
                cornerRadius: WalletConnectProposalLogoView.Layout.cornerRadius,
                style: .continuous
            )
        )
    }
}
