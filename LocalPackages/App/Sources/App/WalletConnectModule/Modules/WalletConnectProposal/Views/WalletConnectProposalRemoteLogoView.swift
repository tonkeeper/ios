import SwiftUI
import TKUIKit

struct WalletConnectProposalRemoteLogoView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                let iconSource = DappIconSource(url: url)
                TKRemoteImage(
                    source: iconSource.source,
                    alternativeSources: iconSource.alternativeSources
                ) {
                    ShimmerSwiftUIView(
                        config: ShimmerSwiftUIView.Config(
                            color: .backgroundContentTint,
                            cornerRadius: .value(WalletConnectProposalLogoView.Layout.cornerRadius)
                        )
                    )
                } failure: {
                    placeholder
                }
            } else {
                placeholder
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

    private var placeholder: some View {
        SwiftUI.Image.TKUIKit.Icons.Size44.placeholder
            .resizable()
            .scaledToFit()
            .padding(14)
    }
}
