import SwiftUI

public struct IconButtonViewPreviews: View {
    @State private var shimmering: Bool = false

    public init() {}

    let contents = [
        IconButtonViewContent(
            icon: .TKUIKit.Icons.Size28.arrowUpOutline,
            title: "Withdraw"
        ),
        IconButtonViewContent(
            icon: .TKUIKit.Icons.Size28.arrowDownOutline,
            title: "Deposit"
        ),
        IconButtonViewContent(
            icon: .TKUIKit.Icons.Size28.swapHorizontalOutline,
            title: "Swap"
        ),
        IconButtonViewContent(
            icon: .TKUIKit.Icons.Size28.stakingOutline,
            title: "Stake"
        ),
    ]

    public var body: some View {
        VStack {
            Toggle(isOn: $shimmering) {
                Text("shimmering")
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
            }
            .padding(.all, 16)

            let configs: [IconButtonViewConfig] = shimmering ? contents.map { _ in
                .shimmer(hasTitle: true)
            } : contents.map(IconButtonViewConfig.content)

            HStack {
                Spacer(minLength: 0)
                ForEach(configs, id: \.self) { config in
                    IconButtonView(config: config)
                    Spacer(minLength: 0)
                }
            }

            let configsIconsOnly = shimmering ? contents.map { _ in
                .shimmer(hasTitle: false)
            } : contents.map {
                IconButtonViewContent(icon: $0.icon)
            }.map(IconButtonViewConfig.content)

            HStack {
                Spacer(minLength: 0)
                ForEach(configsIconsOnly, id: \.self) { config in
                    IconButtonView(config: config)
                    Spacer(minLength: 0)
                }
            }
        }
        .debugPreview(background: .page)
    }
}

#Preview {
    IconButtonViewPreviews()
        .tkThemed()
}
