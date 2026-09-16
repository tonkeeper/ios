import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

@available(iOS 17.0, *)
#Preview("NFT") {
    detailsPreview(model: .previewNFT)
}

@available(iOS 17.0, *)
#Preview("Sent") {
    detailsPreview(model: .previewSent)
}

@available(iOS 17.0, *)
#Preview("Swap") {
    detailsPreview(model: .previewSwap)
}

@available(iOS 17.0, *)
#Preview("Pending Send") {
    detailsPreview(model: .previewPendingSend)
}

@available(iOS 17.0, *)
#Preview("Pending Swap") {
    detailsPreview(model: .previewPendingSwap)
}

private func detailsPreview(model: MultichainTransactionDetailsModel) -> some View {
    ZStack(alignment: .bottom) {
        TKColor.backgroundOverlayStrong
            .ignoresSafeArea()

        MultichainTransactionDetailsView(
            model: model,
            onOpenTransaction: { _, _ in },
            onCopy: { _ in }
        )
    }
    .tkPreviewTheme(.deepBlue)
}

private extension MultichainTransactionDetailsModel {
    static let previewNFT = MultichainTransactionDetailsModel(
        image: .nft(Asset(imageSource: .image(previewArtwork(.artwork)))),
        nft: NFT(
            name: "Mirra Yui",
            collectionName: "Annihilation",
            isVerified: true
        ),
        amountLines: [AmountLine(amount: "NFT", chain: nil)],
        fiat: nil,
        date: "Sent on 2 Sep, 17:32",
        rows: [
            .address(
                type: "Recipient address",
                address: "EQCONmollH5o17uo1YWTU8lS0lS3ZFAM421u531UK4x7oLU"
            ),
            .network(
                title: "Network",
                name: TKThemedText("TON", color: .textPrimary),
                type: "TON"
            ),
            .fee(title: "Fee", amount: "0.0074 TON", fiatAmount: "$ 0.03"),
        ],
        transactionButton: previewTransactionButton
    )

    static let previewSent = MultichainTransactionDetailsModel(
        image: .single(Asset(imageSource: .image(previewArtwork(.token)))),
        amountLines: [AmountLine(amount: "\u{2212}125.5 USDT", chain: "Ethereum")],
        fiat: "$ 125.49",
        date: "Sent on 2 Sep, 17:32",
        rows: [
            .address(
                type: "Recipient address",
                address: "0x2170Ed0880ac9A755fd29B2688956BD959F933F8"
            ),
            .comment(title: "Comment", value: "Thanks!"),
            .network(
                title: "Network",
                name: TKThemedText("Ethereum", color: .textPrimary),
                type: "ERC20"
            ),
            .fee(title: "Fee", amount: "0.0021 ETH", fiatAmount: "$ 7.14"),
            .txHash(
                title: "Tx hash",
                hash: "0x19e1051d6ac04cbf9d2b7c5aa3b1de60a1a9de5f4c1d8a5b0e6318cde"
            ),
        ],
        transactionButton: previewTransactionButton
    )

    static let previewSwap = MultichainTransactionDetailsModel(
        image: .swap(
            left: Asset(imageSource: .image(previewArtwork(.token))),
            right: Asset(imageSource: .image(previewArtwork(.artwork)))
        ),
        amountLines: [
            AmountLine(amount: "\u{2212}125.5 USDT", chain: "Ethereum"),
            AmountLine(amount: "+42.17 TON", chain: nil),
        ],
        fiat: "$ 125.49",
        date: "Swapped on 2 Sep, 17:32",
        rows: [
            .address(
                type: "Recipient",
                address: "EQCONmollH5o17uo1YWTU8lS0lS3ZFAM421u531UK4x7oLU"
            ),
            .network(
                title: "Network",
                name: TKThemedText(spans: [
                    .init("Ethereum ", color: .textPrimary),
                    .init("\u{2192} ", color: .textSecondary),
                    .init("TON", color: .textPrimary),
                ]),
                type: "ERC20 \u{2192} TON"
            ),
            .fee(title: "Fee", amount: "0.0021 ETH", fiatAmount: "$ 7.14"),
        ],
        transactionButton: previewTransactionButton
    )

    static let previewPendingSend = MultichainTransactionDetailsModel(
        image: .single(Asset(imageSource: .image(previewArtwork(.token)))),
        amountLines: [AmountLine(amount: "\u{2212}125.5 USDT", chain: "Ethereum")],
        fiat: "$ 125.49",
        date: "Sent on 2 Sep, 17:32",
        pendingTitle: TKLocales.ActionTypes.sending,
        rows: [
            .address(
                type: "Recipient address",
                address: "0x2170Ed0880ac9A755fd29B2688956BD959F933F8"
            ),
            .network(
                title: "Network",
                name: TKThemedText("Ethereum", color: .textPrimary),
                type: "ERC20"
            ),
            .fee(title: "Fee", amount: "0.0021 ETH", fiatAmount: "$ 7.14"),
        ],
        transactionButton: previewTransactionButton
    )

    static let previewPendingSwap = MultichainTransactionDetailsModel(
        image: .swap(
            left: Asset(imageSource: .image(previewArtwork(.token))),
            right: Asset(imageSource: .image(previewArtwork(.artwork)))
        ),
        amountLines: [
            AmountLine(amount: "\u{2212}125.5 USDT", chain: "Ethereum"),
            AmountLine(amount: "-", chain: nil),
        ],
        fiat: "$ 125.49",
        date: "2 Sep, 17:32",
        pendingTitle: TKLocales.ActionTypes.swapping,
        rows: [
            .network(
                title: "Network",
                name: TKThemedText(spans: [
                    .init("Ethereum ", color: .textPrimary),
                    .init("\u{2192} ", color: .textSecondary),
                    .init("TON", color: .textPrimary),
                ]),
                type: "ERC20 \u{2192} TON"
            ),
            .fee(title: "Fee", amount: "0.0021 ETH", fiatAmount: "$ 7.14"),
        ],
        transactionButton: previewTransactionButton
    )

    static var previewTransactionButton: TransactionButton? {
        guard let url = URL(string: "https://tonviewer.com") else {
            return nil
        }
        return TransactionButton(
            title: TKThemedText(spans: [
                .init(TKLocales.EventDetails.transaction, color: .textPrimary),
                .init("4d1e1608", color: .textSecondary),
            ]),
            url: url,
            browserTitle: nil
        )
    }
}

private enum PreviewArtwork {
    case artwork
    case token
}

private func previewArtwork(_ kind: PreviewArtwork) -> UIImage {
    let size = CGSize(width: 96, height: 96)
    let background: UIColor
    let foreground: UIColor
    switch kind {
    case .artwork:
        background = UIColor(red: 0.16, green: 0.22, blue: 0.33, alpha: 1)
        foreground = UIColor(red: 0.55, green: 0.68, blue: 0.85, alpha: 1)
    case .token:
        background = UIColor(red: 0.11, green: 0.45, blue: 0.78, alpha: 1)
        foreground = UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1)
    }

    return UIGraphicsImageRenderer(size: size).image { context in
        background.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        foreground.setFill()
        context.cgContext.fillEllipse(
            in: CGRect(x: 24, y: 24, width: 48, height: 48)
        )
    }
}
