import SwiftUI

struct BalanceHeaderBalanceStatusViewPreviews: View {
    init() {}

    private var configs: [PreviewConfig] {
        [
            PreviewConfig(
                title: "Address",
                config: BalanceHeaderBalanceStatusViewConfig(
                    state: .address("UQDx...sf92", tags: [])
                )
            ),
            PreviewConfig(
                title: "Address with chevron",
                config: BalanceHeaderBalanceStatusViewConfig(
                    state: .address("UQF2...G2jJ", tags: [], showsChevron: true)
                )
            ),
            PreviewConfig(
                title: "Address with tags",
                config: BalanceHeaderBalanceStatusViewConfig(
                    state: .address(
                        "UQDx...sf92",
                        tags: [
                            .tag(text: "v4r2"),
                            .accentTag(text: "w5", accent: .accentBlue),
                        ]
                    )
                )
            ),
            PreviewConfig(
                title: "Long address",
                config: BalanceHeaderBalanceStatusViewConfig(
                    state: .address(
                        "UQDxzbcLzjNqQp5sGzj4wEGMMeEuP6eqxEGEcPlBrsf92",
                        tags: [
                            .outlintTag(text: "watch"),
                        ]
                    )
                )
            ),
            PreviewConfig(
                title: "Updated",
                config: BalanceHeaderBalanceStatusViewConfig(
                    state: .updated("Updated at 12:48")
                )
            ),
            PreviewConfig(
                title: "Updating",
                config: BalanceHeaderBalanceStatusViewConfig(
                    state: .connection(BalanceHeaderBalanceStatusViewConfig.ConnectionStatus(
                        title: "Updating",
                        titleColor: .textSecondary,
                        isLoading: true
                    ))
                )
            ),
            PreviewConfig(
                title: "No internet",
                config: BalanceHeaderBalanceStatusViewConfig(
                    state: .connection(BalanceHeaderBalanceStatusViewConfig.ConnectionStatus(
                        title: "No internet connection",
                        titleColor: .accentOrange,
                        isLoading: false
                    ))
                )
            ),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(configs, id: \.self) { previewConfig in
                VStack(alignment: .leading, spacing: 8) {
                    Text(previewConfig.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)

                    BalanceHeaderBalanceStatusView(config: previewConfig.config)
                }
            }
        }
        .padding(.all, 16)
        .debugPreview()
    }
}

private extension BalanceHeaderBalanceStatusViewPreviews {
    struct PreviewConfig: Hashable {
        let title: String
        let config: BalanceHeaderBalanceStatusViewConfig
    }
}

#Preview {
    BalanceHeaderBalanceStatusViewPreviews()
        .tkThemed()
}
