import SwiftUI

public struct WalletConnectBalanceCellContent {
    public let title: String
    public let balance: String?

    public init(
        title: String,
        balance: String?
    ) {
        self.title = title
        self.balance = balance
    }
}

public struct WalletConnectBalanceCell: View {
    public let content: WalletConnectBalanceCellContent
    public let showsSwitch: Bool
    public let action: (() -> Void)?

    public init(
        content: WalletConnectBalanceCellContent,
        showsSwitch: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.content = content
        self.showsSwitch = showsSwitch
        self.action = action
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                action: action
            ),
            leading: {
                CellAssetLeading {
                    Circle()
                        .fill(.backgroundContentTint)
                        .overlay {
                            ZStack(alignment: .center) {
                                SwiftUI.Image.TKUIKit.Icons.Size16.wallet
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.iconPrimary)
                                    .frame(
                                        width: Layout.walletIconSize,
                                        height: Layout.walletIconSize
                                    )
                            }
                        }
                }
            },
            center: {
                CellCenter(
                    primaryRow: {
                        CellCenterPrimaryRow(
                            config: .content(
                                CellCenterPrimaryRow.Content(
                                    title: content.title
                                )
                            )
                        )
                    },
                    secondaryRow: {
                        if let balance = content.balance {
                            CellCenterSecondaryRow(
                                config: .content(
                                    CellCenterSecondaryRow.Content(
                                        value: CellCenterSecondaryRow.ValueConfig(
                                            title: balance
                                        )
                                    )
                                )
                            )
                        } else {
                            EmptyView()
                        }
                    }
                )
            },
            trailing: {
                if showsSwitch {
                    CellTrailingAccessory(
                        config: CellTrailingAccessory.Config(
                            color: .iconTertiary,
                            icon: SwiftUI.Image.TKUIKit.Icons.Size16.switch,
                            iconSize: Layout.switchIconSize,
                            contentInsetsModifier: {
                                $0.trailing = 22
                            }
                        )
                    )
                } else {
                    EmptyView()
                }
            }
        )
    }
}

private extension WalletConnectBalanceCell {
    enum Layout {
        static let walletIconSize: CGFloat = 24
        static let switchIconSize: CGFloat = 16
    }
}
