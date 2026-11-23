import SwiftUI
import TKLocalize
import TKUIKit

public struct BatterySupportedTransactionsView: View {
    public struct Network: Identifiable {
        public let id: String
        public let title: String
        public let rows: [Row]

        public init(id: String, title: String, rows: [Row]) {
            self.id = id
            self.title = title
            self.rows = rows
        }
    }

    public struct Row: Identifiable {
        public let id: String
        public let title: String
        public let caption: String

        public init(id: String, title: String, caption: String) {
            self.id = id
            self.title = title
            self.caption = caption
        }
    }

    private let networks: [Network]
    private let onBack: (() -> Void)?
    private let onClose: (() -> Void)?
    @State private var selectedNetworkID: String?
    @State private var networkTitleAnchorView: UIView?

    public init(networks: [Network], onBack: (() -> Void)?, onClose: (() -> Void)?) {
        self.networks = networks
        self.onBack = onBack
        self.onClose = onClose
    }

    private var selectedNetwork: Network? {
        networks.first { $0.id == selectedNetworkID } ?? networks.first
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            if let selectedNetwork {
                VStack(spacing: 0) {
                    networkTitle(selectedNetwork)
                    rows(selectedNetwork.rows)
                }
                .padding(.bottom, Layout.listVerticalPadding)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            DefaultModalCardHeader(config: headerConfig)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }

    private func networkTitle(_ network: Network) -> some View {
        ListTitleView(
            config: .text(
                TKLocales.FeeMethodPicker.title,
                accessory: ListTitleView.Accessory(
                    title: network.title,
                    icon: networks.count > 1 ? .TKUIKit.Icons.Size16.chevronDown : nil,
                    action: showNetworkMenu
                )
            )
        )
        .padding(.horizontal, Layout.horizontalPadding)
        .background(AnchorViewResolver { networkTitleAnchorView = $0 })
        .accessibilityIdentifier("battery_supported_transactions_network")
    }

    private func rows(_ rows: [Row]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                Cell(
                    config: Cell.Config(showsDivider: index < rows.count - 1),
                    center: {
                        CellCenter {
                            Text(row.title)
                                .textStyle(.label1)
                                .foregroundStyle(.textPrimary)
                        } secondaryRow: {
                            Text(row.caption)
                                .textStyle(.body2)
                                .foregroundStyle(.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                )
                .accessibilityIdentifier("battery_supported_transaction_\(row.id)")
            }
        }
        .asCellsGroup()
    }

    private func showNetworkMenu() {
        guard networks.count > 1, let networkTitleAnchorView else {
            return
        }
        TKPopupMenuController.show(
            sourceView: networkTitleAnchorView,
            position: .bottomRight(inset: Layout.horizontalPadding),
            minimumWidth: Layout.menuMinimumWidth,
            items: networks.map { network in
                TKPopupMenuItem(title: network.title, selectionHandler: { selectedNetworkID = network.id })
            },
            selectedIndex: networks.firstIndex { $0.id == selectedNetwork?.id }
        )
    }

    private var headerConfig: DefaultModalCardHeader.Config {
        DefaultModalCardHeader.Config(
            leftIcon: onBack.map { onBack in .back { _ in onBack() } },
            title: .init(text: TKLocales.Battery.Refill.transactions),
            rightIcon: onClose.map { onClose in .close { _ in onClose() } },
            background: .scrim
        )
    }

    private enum Layout {
        static let listVerticalPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let menuMinimumWidth: CGFloat = 160
    }
}
