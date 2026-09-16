import SwiftUI
import TKUIKit

struct MultichainTransactionDetailsCell: View {
    @Environment(\.tkPalette) private var palette

    let content: MultichainTransactionDetailsCellContent
    let showsDivider: Bool
    let onCopy: (String) -> Void
    let contentInsets: (inout EdgeInsets) -> Void = {
        $0.top += 2
        $0.bottom += 2
    }

    init(
        content: MultichainTransactionDetailsCellContent,
        showsDivider: Bool = false,
        onCopy: @escaping (String) -> Void = { _ in }
    ) {
        self.content = content
        self.showsDivider = showsDivider
        self.onCopy = onCopy
    }

    private var tapAction: (() -> Void)? {
        switch content {
        case let .address(_, value), let .txHash(_, value):
            return { onCopy(value) }
        default:
            return nil
        }
    }

    var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                showsDivider: showsDivider,
                action: tapAction
            ),
            center: {
                switch content {
                case let .address(type, value), let .txHash(type, value):
                    CellCenter(
                        primaryRow: {
                            CellCenterPrimaryRow(
                                config: .content(
                                    CellCenterPrimaryRow.Content(
                                        title: CellCenterPrimaryRow.TitleConfig(
                                            text: type,
                                            color: .textSecondary,
                                            style: .body1
                                        )
                                    )
                                )
                            )
                        },
                        secondaryRow: {
                            CellCenterSecondaryRow(
                                config: .content(
                                    CellCenterSecondaryRow.Content(
                                        value: CellCenterSecondaryRow.ValueConfig(
                                            title: value,
                                            textStyle: .label1,
                                            textColor: .textPrimary,
                                            truncationMode: .middle
                                        )
                                    )
                                )
                            )
                        },
                        contentInsets: contentInsets
                    )
                case let .network(title, name, type):
                    CellCenter(
                        primaryRow: {
                            CellCenterPrimaryRow(
                                config: .content(
                                    CellCenterPrimaryRow.Content(
                                        title: CellCenterPrimaryRow.TitleConfig(
                                            text: title,
                                            color: .textSecondary,
                                            style: .body1
                                        ),
                                        value: CellCenterPrimaryRow.ValueConfig(
                                            title: name.resolve(palette)
                                        )
                                    )
                                )
                            )
                        },
                        secondaryRow: {
                            CellCenterSecondaryRow(
                                config: .content(
                                    CellCenterSecondaryRow.Content(
                                        accessory: CellCenterSecondaryRow.AccessoryConfig(
                                            title: type,
                                            textStyle: .body2,
                                            color: .textSecondary
                                        )
                                    )
                                )
                            )
                        },
                        contentInsets: contentInsets
                    )
                case let .fee(title, amount, fiatAmount):
                    CellCenter(
                        primaryRow: {
                            CellCenterPrimaryRow(
                                config: .content(
                                    CellCenterPrimaryRow.Content(
                                        title: CellCenterPrimaryRow.TitleConfig(
                                            text: title,
                                            color: .textSecondary,
                                            style: .body1
                                        ),
                                        value: CellCenterPrimaryRow.ValueConfig(
                                            title: amount
                                        )
                                    )
                                )
                            )
                        },
                        secondaryRow: {
                            CellCenterSecondaryRow(
                                config: .content(
                                    CellCenterSecondaryRow.Content(
                                        accessory: fiatAmount.flatMap { fiatAmount in
                                            CellCenterSecondaryRow.AccessoryConfig(
                                                title: fiatAmount,
                                                textStyle: .body2,
                                                color: .textSecondary,
                                                truncationMode: .middle
                                            )
                                        }
                                    )
                                )
                            )
                        },
                        contentInsets: contentInsets
                    )
                case let .comment(title, value), let .property(title, value):
                    CellCenter(
                        primaryRow: {
                            CellCenterPrimaryRow(
                                config: .content(
                                    CellCenterPrimaryRow.Content(
                                        title: CellCenterPrimaryRow.TitleConfig(
                                            text: title,
                                            color: .textSecondary,
                                            style: .body1
                                        ),
                                        value: CellCenterPrimaryRow.ValueConfig(
                                            title: value
                                        )
                                    )
                                )
                            )
                        },
                        contentInsets: contentInsets
                    )
                }
            }
        )
    }
}
