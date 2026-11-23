import SwiftUI
import TKLocalize
import TKUIKit

/// The tokens folded into Other tokens, with a chain filter once they span several chains.
public struct BatteryOtherTokensView: View {
    private let tokens: [(id: String, token: BatteryRefillViewState.PaymentMethod.OtherToken)]
    private let chains: [BatteryRefillViewState.PaymentMethod.Chain]
    private let onSelect: (String) -> Void
    @State private var selectedChainID: String?

    public init(methods: [BatteryRefillViewState.PaymentMethod], onSelect: @escaping (String) -> Void) {
        let tokens = methods.compactMap { method in method.otherToken.map { (id: method.id, token: $0) } }
        var chains: [BatteryRefillViewState.PaymentMethod.Chain] = []
        for chain in tokens.map(\.token.chain) where !chains.contains(where: { $0.id == chain.id }) {
            chains.append(chain)
        }
        self.tokens = tokens
        self.chains = chains
        self.onSelect = onSelect
    }

    private var shownTokens: [(id: String, token: BatteryRefillViewState.PaymentMethod.OtherToken)] {
        guard let selectedChainID else { return tokens }
        return tokens.filter { $0.token.chain.id == selectedChainID }
    }

    public var body: some View {
        VStack(spacing: 0) {
            if chains.count > 1 {
                TabCategoriesView<String?>(
                    items: [.init(id: nil, title: TKLocales.History.Tab.all, accessibilityIdentifier: "battery_other_tokens_chain_all")]
                        + chains.map { chain in
                            .init(
                                id: chain.id,
                                title: chain.title,
                                image: chain.image,
                                accessibilityIdentifier: "battery_other_tokens_chain_\(chain.id)"
                            )
                        },
                    initialSelection: nil,
                    onSelectionChange: { selectedChainID = $0 },
                    style: .secondary,
                    insetsModifier: {
                        $0.top = 0
                        $0.bottom = Layout.chipsBottomPadding
                    }
                )
            }
            let shown = shownTokens
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                    AssetBalanceRowCell(
                        config: .content(item.token.row),
                        showsDivider: index < shown.count - 1,
                        action: { onSelect(item.id) }
                    )
                    .accessibilityIdentifier("battery_other_tokens_\(item.id)")
                }
            }
            .asCellsGroup()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("battery_other_tokens_list")
        }
        .padding(.bottom, Layout.bottomPadding)
    }

    private enum Layout {
        static let chipsBottomPadding: CGFloat = 12
        static let bottomPadding: CGFloat = 16
    }
}
