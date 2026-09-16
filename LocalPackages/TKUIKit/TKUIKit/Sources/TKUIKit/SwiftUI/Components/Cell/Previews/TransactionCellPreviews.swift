import SwiftUI
import UIKit

public struct TransactionCellPreviews: View {
    @Environment(\.tkPalette) private var palette

    public init() {}

    public var body: some View {
        let items = previewItems

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Transactions")
                    .textStyle(.h3)
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)

                VStack(spacing: 0) {
                    ForEach(Array(items.indices), id: \.self) { index in
                        TransactionCell(
                            config: .content(items[index])
                        )
                        .background(.backgroundContent)
                        .padding(.bottom, index == 0 ? 15 : 16)
                    }
                }
            }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }

    private var previewItems: [TransactionCellContent] {
        [
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.trayArrowDown),
                title: "Operation Name",
                subtitle: .init(
                    text: "Address",
                    style: .primary
                ),
                amount: .init(
                    title: "Amount",
                    style: .primary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                details: .init(
                    title: .init(text: "Left description"),
                    accessory: .init(text: "Right description")
                ),
                nftPreview: nftPreview,
                messages: [
                    .init(
                        id: "thanks",
                        text: "Thanks!",
                        style: .compact
                    ),
                    .init(
                        id: "never-gonna",
                        text: "Never gonna give you up\nNever gonna let you down"
                    ),
                ]
            ),
            simpleItem(
                title: "Sent",
                subtitle: "UQAK…MALX",
                amountText: "− 400.31 TON",
                icon: historyIcon(.TKUIKit.Icons.Size28.trayArrowUp)
            ),
            simpleItem(
                title: "Received",
                subtitle: "UQAK…MALX",
                amountText: "+ 400.31 TON",
                amountStyle: .positive,
                icon: historyIcon(.TKUIKit.Icons.Size28.trayArrowDown)
            ),
            simpleItem(
                title: "Spam",
                subtitle: "UQAK…MALX",
                subtitleStyle: .disabled,
                amountText: "+ 0.000001 TON",
                amountStyle: .tertiary,
                icon: historyIcon(.TKUIKit.Icons.Size28.trayArrowDown)
            ),
            simpleItem(
                title: "Bounced",
                subtitle: "UQAK…MALX",
                amountText: "+ 400.31 TON",
                amountStyle: .positive,
                icon: historyIcon(.TKUIKit.Icons.Size28.return)
            ),
            simpleItem(
                title: "Received credit card",
                subtitle: "UQAK…MALX",
                amountText: "+ 400.31 TON",
                amountStyle: .positive,
                icon: historyIcon(.TKUIKit.Icons.Size28.creditCard)
            ),
            simpleItem(
                title: "Purchased",
                subtitle: "UQAK…MALX",
                amountText: "+ 400.31 TON",
                icon: historyIcon(.TKUIKit.Icons.Size28.shoppingBag)
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.bell),
                title: "Subscribed",
                subtitle: .init(
                    text: "Subscription name",
                    style: .primary
                ),
                amount: .init(
                    title: "−400.31 TON",
                    style: .primary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                details: .init(
                    title: .init(text: "Premium subscription")
                )
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.xmark),
                title: "Unsubscribed",
                subtitle: .init(
                    text: "Subscription name",
                    style: .primary
                ),
                amount: .init(
                    title: "-",
                    style: .tertiary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                details: .init(
                    title: .init(text: "Premium subscription")
                )
            ),
            simpleItem(
                title: "Wallet Initialized",
                subtitle: "UQAK…MALX",
                amountText: "-",
                amountStyle: .tertiary,
                icon: historyIcon(.TKUIKit.Icons.Size28.donemark)
            ),
            simpleItem(
                title: "NFT Collection Creation",
                subtitle: "UQAK…MALX",
                amountText: "-",
                amountStyle: .tertiary,
                icon: historyIcon(.TKUIKit.Icons.Size28.gear)
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.gear),
                title: "NFT Creation",
                subtitle: .init(
                    text: "UQAK…MALX",
                    style: .primary
                ),
                amount: .init(
                    title: "-",
                    style: .tertiary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                nftPreview: nftPreview
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.xmark),
                title: "Removal from sale",
                subtitle: .init(
                    text: "UQAK…MALX",
                    style: .primary
                ),
                amount: .init(
                    title: "-",
                    style: .tertiary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                nftPreview: nftPreview
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.shoppingBag),
                title: "NFT Purchase",
                subtitle: .init(
                    text: "UQAK…MALX",
                    style: .primary
                ),
                amount: .init(
                    title: "−400.31 TON",
                    style: .primary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                nftPreview: nftPreview
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.trayArrowUp),
                title: "Bid",
                subtitle: .init(
                    text: "UQAK…MALX",
                    style: .primary
                ),
                amount: .init(
                    title: "−400.31 TON",
                    style: .primary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                details: .init(
                    title: .init(text: "Bid for Mirra Yui")
                )
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.trayArrowUp),
                title: "Put up for auction",
                subtitle: .init(
                    text: "UQAK…MALX",
                    style: .primary
                ),
                amount: .init(
                    title: "-",
                    style: .tertiary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                nftPreview: nftPreview
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.xmark),
                title: "End of auction",
                subtitle: .init(
                    text: "UQAK…MALX",
                    style: .primary
                ),
                amount: .init(
                    title: "-",
                    style: .tertiary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                nftPreview: nftPreview
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.trayArrowUp),
                title: "Put up for sale",
                subtitle: .init(
                    text: "UQAK…MALX",
                    style: .primary
                ),
                amount: .init(
                    title: "-",
                    style: .tertiary
                ),
                accessory: .init(
                    text: "17:32"
                ),
                nftPreview: nftPreview
            ),
            .init(
                icon: historyIcon(.TKUIKit.Icons.Size28.swapHorizontalAlternative),
                title: "Swap",
                subtitle: .init(
                    text: "UQAK…MALX",
                    style: .primary
                ),
                amount: .init(
                    title: "+7.21 STON",
                    style: .positive
                ),
                accessory: .init(
                    text: "−7 TON",
                    textStyle: .label1,
                    color: .textPrimary
                ),
                details: .init(
                    accessory: .init(text: "17:32")
                )
            ),
            simpleItem(
                title: "Domain Renew",
                subtitle: "cat.ton",
                amountText: "-",
                amountStyle: .tertiary,
                icon: historyIcon(.TKUIKit.Icons.Size28.renew)
            ),
            simpleItem(
                title: "Link Domain",
                subtitle: "cat.ton",
                amountText: "-",
                amountStyle: .tertiary,
                icon: historyIcon(.TKUIKit.Icons.Size28.linkSquare)
            ),
            simpleItem(
                title: "Unlink Domain",
                subtitle: "cat.ton",
                amountText: "-",
                amountStyle: .tertiary,
                icon: historyIcon(.TKUIKit.Icons.Size28.xmark)
            ),
        ]
    }
}

private extension TransactionCellPreviews {
    var nftPreview: TransactionCellContent.NftPreview {
        .init(
            id: "mirra-yui",
            imageSource: .image(nftPreviewImage),
            title: "Mirra Yui",
            subtitle: "Annihilation",
            isVerified: false
        )
    }

    var nftPreviewImage: UIImage {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let background = UIColor.Background.contentTint
            let text = "MY"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor.Text.primary,
            ]
            let textSize = text.size(withAttributes: attributes)
            let textOrigin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )

            context.cgContext.setFillColor(background.cgColor)
            context.cgContext.fill(rect)
            text.draw(
                at: textOrigin,
                withAttributes: attributes
            )
        }
    }

    func simpleItem(
        title: String,
        subtitle: String,
        subtitleStyle: TransactionCellContent.SubtitleStyle = .primary,
        amountText: String,
        amountStyle: TransactionCellContent.AmountStyle = .primary,
        icon: TransactionCellContent.Icon
    ) -> TransactionCellContent {
        .init(
            icon: icon,
            title: title,
            subtitle: .init(
                text: subtitle,
                style: subtitleStyle
            ),
            amount: .init(
                title: amountText,
                style: amountStyle
            ),
            accessory: .init(
                text: "17:32"
            )
        )
    }

    func historyIcon(_ image: UIImage) -> TransactionCellContent.Icon {
        .init(image: image)
    }
}

#Preview {
    TransactionCellPreviews()
        .tkThemed()
}
