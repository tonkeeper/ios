import SwiftUI

public struct DAppCellContent {
    public typealias ExtraInfo = (source: String, date: String)

    var name: String
    var url: String
    var extraInfo: ExtraInfo?
    var image: AssetAvatarViewImageSource
    var sourceAccent: Color?
    var showSeparator: Bool

    public init(
        name: String,
        url: String,
        extraInfo: ExtraInfo? = nil,
        image: AssetAvatarViewImageSource,
        sourceAccent: Color? = nil,
        showSeparator: Bool
    ) {
        self.name = name
        self.url = url
        self.extraInfo = extraInfo
        self.image = image
        self.sourceAccent = sourceAccent
        self.showSeparator = showSeparator
    }
}

public struct DAppCell: View {
    var content: DAppCellContent
    var onCancel: () -> Void

    public init(
        content: DAppCellContent,
        onCancel: @escaping () -> Void
    ) {
        self.content = content
        self.onCancel = onCancel
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                showsDivider: content.showSeparator
            ),
            leading: {
                CellAssetLeading {
                    avatarView
                }
            },
            center: {
                CellCenter(
                    primaryRow: CellCenterPrimaryRow(
                        config: .content(
                            CellCenterPrimaryRow.Content(
                                title: CellCenterPrimaryRow.TitleConfig(
                                    text: content.name
                                )
                            )
                        )
                    ),
                    secondaryRow: CellCenterSecondaryRow(
                        config: .content(
                            CellCenterSecondaryRow.Content(
                                value: CellCenterSecondaryRow.ValueConfig(
                                    title: {
                                        if let extraInfo = content.extraInfo {
                                            "\(content.url)\n\(extraInfo.source) · \(extraInfo.date)"
                                        } else {
                                            content.url
                                        }
                                    }(),
                                    lineLimit: content.extraInfo == nil ? 1 : 2
                                )
                            )
                        )
                    )
                )
            },
            trailing: {
                Button {
                    onCancel()
                } label: {
                    SwiftUI.Image.TKUIKit.Icons.Size16.close
                        .foregroundStyle(.buttonTertiaryForeground)
                        .frame(width: 16, height: 16)
                        .padding(10)
                        .background(.buttonTertiaryBackground)
                        .clipShape(.circle)
                        .padding(.trailing, 16)
                }
                .buttonStyle(TKTapAnimationButtonStyle())
            }
        )
    }

    private var avatarView: some View {
        AssetAvatarView(
            imageSource: content.image,
            size: .small,
            chainIconBackgroundColor: content.sourceAccent
        )
    }
}

#Preview {
    VStack(spacing: 0) {
        DAppCell(
            content: DAppCellContent(
                name: "Tonstakers",
                url: "app.tonstakers.com",
                extraInfo: (
                    source: "Another device",
                    date: "5 Mar, 14:10"
                ),
                image: .image(.TKUIKit.Icons.Size44.tonStakersLogo, chainIcon: .TKUIKit.Icons.Size20.qrCodeSmall),
                sourceAccent: TKPreview.palette.accent.green,
                showSeparator: true
            ),
            onCancel: {}
        )
        DAppCell(
            content: DAppCellContent(
                name: "Tonstakers",
                url: "app.tonstakers.com",
                image: .image(.TKUIKit.Icons.Size44.tonStakersLogo),
                showSeparator: false
            ),
            onCancel: {}
        )
    }
    .tkThemed()
}
