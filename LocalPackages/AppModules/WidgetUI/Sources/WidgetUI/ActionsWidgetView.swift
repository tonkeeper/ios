import SwiftUI
import TKUIKit
import WidgetKit

public struct ActionsWidgetState {
    public struct Action: Identifiable {
        public enum Kind {
            case send, buy, swap, stake
        }

        public let kind: Kind
        public let title: String
        /// `nil` while the wallet cannot take the action: the tile is dimmed and opens the app.
        public let url: URL?

        public var id: Kind {
            kind
        }

        public init(kind: Kind, title: String, url: URL?) {
            self.kind = kind
            self.title = title
            self.url = url
        }
    }

    public let wallet: WidgetWallet
    public let total: String?
    public let decimalSeparator: String
    public let hidesAmounts: Bool
    public let actions: [Action]

    public init(wallet: WidgetWallet, total: String?, decimalSeparator: String, hidesAmounts: Bool, actions: [Action]) {
        self.wallet = wallet
        self.total = total
        self.decimalSeparator = decimalSeparator
        self.hidesAmounts = hidesAmounts
        self.actions = actions
    }
}

@available(iOS 17.0, *)
public struct ActionsWidgetView: View {
    let state: ActionsWidgetState
    let family: WidgetFamily

    public init(state: ActionsWidgetState, family: WidgetFamily) {
        self.state = state
        self.family = family
    }

    public var body: some View {
        if family == .systemMedium {
            medium
        } else {
            small
        }
    }

    private var small: some View {
        let rows = stride(from: 0, to: state.actions.count, by: 2).map { Array(state.actions[$0 ..< min($0 + 2, state.actions.count)]) }
        return VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    ForEach(rows[index]) { ActionsWidgetTile(action: $0, iconSize: 24) }
                }
            }
        }
        .padding(16)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetWalletView(wallet: state.wallet)
                    WidgetAmountText(
                        text: state.hidesAmounts ? WidgetTheme.hiddenAmount : state.total ?? "—",
                        decimalSeparator: state.decimalSeparator,
                        style: .num2,
                        fractionStyle: Self.fractionStyle
                    )
                }
                Spacer(minLength: 0)
                WidgetLogoView()
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                ForEach(state.actions) { ActionsWidgetTile(action: $0, iconSize: 28) }
            }
            .frame(height: 64)
        }
        .padding(16)
    }

    /// Figma's 24/32 cents of a 28/36 amount; the design system has no medium 24.
    private static let fractionStyle = TKTextStyle(font: .tkMedium(size: 24, features: .display), lineHeight: 32)
}

@available(iOS 17.0, *)
private struct ActionsWidgetTile: View {
    let action: ActionsWidgetState.Action
    let iconSize: CGFloat

    var body: some View {
        if let url = action.url {
            Link(destination: url) { label }
        } else {
            label.opacity(0.48)
        }
    }

    private var label: some View {
        VStack(spacing: 4) {
            icon
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.iconPrimary)
                .frame(width: iconSize, height: iconSize)
            Text(action.title)
                .textStyle(.label3)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.backgroundContentTint))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(action.title)
        .accessibilityAddTraits(.isButton)
    }

    private var icon: Image {
        switch action.kind {
        case .send: .TKUIKit.Icons.Size28.arrowUpOutline
        case .buy: .TKUIKit.Icons.Size28.arrowDownOutline
        case .swap: .TKUIKit.Icons.Size28.swapHorizontalOutline
        case .stake: .TKUIKit.Icons.Size28.stakingOutline
        }
    }
}
