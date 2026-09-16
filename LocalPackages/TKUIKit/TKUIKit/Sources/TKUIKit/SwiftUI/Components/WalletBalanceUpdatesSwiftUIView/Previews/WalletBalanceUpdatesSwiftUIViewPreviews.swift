import SwiftUI

struct WalletBalanceUpdatesSwiftUIViewPreviews: View {
    private let configs: [PreviewConfig] = [
        PreviewConfig(
            title: "All updates",
            config: WalletBalanceUpdatesSwiftUIViewConfig(
                title: "All updates"
            )
        ),
        PreviewConfig(
            title: "Story",
            config: WalletBalanceUpdatesSwiftUIViewConfig(
                title: "Gasless transactions",
                icon: .image(.TKUIKit.Icons.Size16.wallet)
            )
        ),
        PreviewConfig(
            title: "Long story",
            config: WalletBalanceUpdatesSwiftUIViewConfig(
                title: "A very long update title that should be truncated",
                icon: .image(.TKUIKit.Icons.Size16.wallet)
            )
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(configs, id: \.self) { previewConfig in
                VStack(alignment: .leading, spacing: 8) {
                    Text(previewConfig.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)

                    WalletBalanceUpdatesSwiftUIView(config: previewConfig.config)
                }
            }
        }
        .padding(.all, 16)
        .debugPreview(background: .page)
    }
}

private extension WalletBalanceUpdatesSwiftUIViewPreviews {
    struct PreviewConfig: Hashable {
        let title: String
        let config: WalletBalanceUpdatesSwiftUIViewConfig
    }
}

#Preview {
    WalletBalanceUpdatesSwiftUIViewPreviews()
        .tkThemed()
}
