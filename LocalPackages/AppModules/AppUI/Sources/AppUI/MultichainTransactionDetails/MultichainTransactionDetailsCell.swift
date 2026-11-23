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
        case let .address(_, value), let .txHash(_, value), let .inlineHash(_, value):
            return { onCopy(value) }
        case let .encryptedComment(_, _, decrypt):
            return decrypt
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
                case let .fee(title, amount, fiatAmount), let .value(title, amount, fiatAmount):
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
                    propertyRow(title: title, value: value, color: .textPrimary)
                case let .encryptedComment(title, length, _):
                    encryptedCommentRow(title: title, length: length)
                case let .status(title, value, color, isPending):
                    propertyRow(title: title, value: value, color: color, isPending: isPending)
                case let .inlineHash(title, hash):
                    propertyRow(title: title, value: Self.shortHash(hash), color: .textPrimary)
                }
            }
        )
    }

    private func propertyRow(title: String, value: String, color: TKColor, isPending: Bool = false) -> some View {
        CellCenter(
            primaryRow: {
                HStack(spacing: 6) {
                    CellCenterPrimaryRow(
                        config: .content(
                            CellCenterPrimaryRow.Content(
                                title: CellCenterPrimaryRow.TitleConfig(
                                    text: title,
                                    color: .textSecondary,
                                    style: .body1
                                ),
                                value: CellCenterPrimaryRow.ValueConfig(
                                    title: value,
                                    color: color
                                )
                            )
                        )
                    )

                    if isPending { MultichainTransactionPendingLoader() }
                }
            },
            contentInsets: contentInsets
        )
    }

    private func encryptedCommentRow(title: String, length: Int) -> some View {
        CellCenter(
            primaryRow: {
                HStack(spacing: 4) {
                    Text(title)
                        .textStyle(.body1)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                    Image(uiImage: .TKUIKit.Icons.Size12.lock)
                        .renderingMode(.template)
                        .foregroundStyle(.accentGreen)
                    Spacer(minLength: 16)
                    Text(String(repeating: "0", count: max(length, 1)))
                        .textStyle(.label1)
                        .lineLimit(1)
                        .hidden()
                        .overlay(TKSpoiler())
                }
            },
            contentInsets: contentInsets
        )
    }

    static func shortHash(_ hash: String) -> String {
        let part = 8
        guard hash.count > part * 2 + 1 else { return hash }
        return "\(hash.prefix(part))…\(hash.suffix(part))"
    }
}
