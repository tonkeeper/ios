import Foundation
import SwiftUI
import TKUIKit

public struct MultichainTransactionDetailsView: View {
    @Environment(\.tkPalette) private var palette

    let model: MultichainTransactionDetailsModel
    let onOpenTransaction: (URL, String?) -> Void
    let onCopy: (String) -> Void

    public init(
        model: MultichainTransactionDetailsModel,
        onOpenTransaction: @escaping (URL, String?) -> Void,
        onCopy: @escaping (String) -> Void
    ) {
        self.model = model
        self.onOpenTransaction = onOpenTransaction
        self.onCopy = onCopy
    }

    public var body: some View {
        VStack(spacing: 0) {
            hero
            detailsList
            transactionButton
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension MultichainTransactionDetailsView {
    var hero: some View {
        VStack(spacing: 0) {
            heroImage
                .padding(.bottom, Layout.heroImageBottomPadding)

            if let nft = model.nft {
                nftContent(nft)
            } else {
                amountContent
            }
        }
        .frame(maxWidth: .infinity)
    }

    var amountContent: some View {
        VStack(spacing: -3) {
            ForEach(model.amountLines.indices, id: \.self) { index in
                amountLineText(model.amountLines[index])
                    .textStyle(.h2)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let fiat = model.fiat {
                Text(fiat)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .padding(.top, 7)
            }

            Text(model.date)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .padding(.top, 7)

            if let pendingTitle = model.pendingTitle {
                pendingStatus(pendingTitle)
                    .padding(.top, 7)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, Layout.heroTopPadding)
        .padding(.horizontal, Layout.heroHorizontalPadding)
        .padding(.bottom, Layout.heroBottomPadding)
    }

    func nftContent(_ nft: MultichainTransactionDetailsModel.NFT) -> some View {
        VStack(spacing: Layout.heroTextSpacing) {
            Text(nft.name)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)

            HStack(spacing: Layout.nftVerificationSpacing) {
                Text(nft.collectionName)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)

                if nft.isVerified {
                    SwiftUI.Image.TKUIKit.Icons.Size16.verification
                        .renderingMode(.template)
                        .foregroundStyle(.iconSecondary)
                        .frame(
                            width: Layout.nftVerificationIconSize,
                            height: Layout.nftVerificationIconSize
                        )
                }
            }
            .padding(.top, -1)

            Text(model.date)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .padding(.top, 1)

            if let pendingTitle = model.pendingTitle {
                pendingStatus(pendingTitle)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.heroHorizontalPadding)
        .padding(.bottom, Layout.nftContentBottomPadding)
    }

    func pendingStatus(_ pendingTitle: String) -> some View {
        HStack(spacing: Layout.pendingStatusSpacing) {
            Text(pendingTitle)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)

            CircularLoader(
                mode: .indeterminate,
                preset: .custom(
                    CircularLoaderConfiguration(
                        lineWidth: Layout.pendingLoaderLineWidth,
                        progressColor: palette.icon.secondary,
                        trackColor: palette.icon.secondary.opacity(Layout.pendingLoaderTrackOpacity),
                        size: CGSize(
                            width: Layout.pendingLoaderSize,
                            height: Layout.pendingLoaderSize
                        ),
                        contentPadding: 0
                    )
                )
            )
        }
    }

    func amountLineText(_ amountLine: MultichainTransactionDetailsModel.AmountLine) -> Text {
        var text = Text(amountLine.amount)
            .foregroundColor(palette.text.primary)

        if let chain = amountLine.chain {
            text = text
                + Text(" \(chain)")
                .foregroundColor(palette.text.tertiary)
        }

        return text
    }

    @ViewBuilder
    var heroImage: some View {
        switch model.image {
        case let .single(asset):
            AssetAvatarView(
                imageSource: asset.imageSource,
                size: .extraLarge,
                chainIconPosition: .trailing
            )
        case let .nft(asset):
            AssetAvatarView(
                imageSource: asset.imageSource,
                size: .extraLarge,
                shape: .rectangle(cornerRadius: Layout.nftImageCornerRadius)
            )
        case let .swap(left, right):
            SwapAssetAvatarView(
                left: left,
                right: right
            )
        }
    }

    var detailsList: some View {
        VStack(spacing: 0) {
            ForEach(model.rows.indices, id: \.self) { index in
                MultichainTransactionDetailsCell(
                    content: model.rows[index],
                    showsDivider: index + 1 < model.rows.count,
                    onCopy: onCopy
                )
            }
        }
        .background(.backgroundContent)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Layout.detailsCornerRadius,
                style: .continuous
            )
        )
        .padding(.horizontal, Layout.detailsHorizontalPadding)
        .padding(.bottom, Layout.detailsBottomPadding)
    }

    @ViewBuilder
    var transactionButton: some View {
        if let transactionButton = model.transactionButton {
            ButtonView(
                config: ButtonView.Config(
                    title: transactionButton.title.resolve(palette),
                    size: .small,
                    appearance: .secondary,
                    icon: ButtonView.Icon(
                        image: .TKUIKit.Icons.Size16.globe,
                        alignment: .leading
                    ),
                    action: {
                        onOpenTransaction(
                            transactionButton.url,
                            transactionButton.browserTitle
                        )
                    }
                )
            )
            .padding(.top, Layout.transactionButtonTopPadding)
            .padding(.bottom, Layout.transactionButtonBottomPadding)
        }
    }

    enum Layout {
        static let nftImageCornerRadius: CGFloat = 20
        static let nftContentBottomPadding: CGFloat = 30
        static let nftVerificationSpacing: CGFloat = 4
        static let nftVerificationIconSize: CGFloat = 16
        static let heroImageBottomPadding: CGFloat = 20
        static let heroTextSpacing: CGFloat = 4
        static let heroTopPadding: CGFloat = 1
        static let heroHorizontalPadding: CGFloat = 32
        static let heroBottomPadding: CGFloat = 31
        static let pendingStatusSpacing: CGFloat = 6
        static let pendingLoaderSize: CGFloat = 14
        static let pendingLoaderLineWidth: CGFloat = 2
        static let pendingLoaderTrackOpacity: Double = 0.32
        static let detailsHorizontalPadding: CGFloat = 16
        static let detailsBottomPadding: CGFloat = 16
        static let detailsCornerRadius: CGFloat = 16
        static let transactionButtonTopPadding: CGFloat = 16
        static let transactionButtonBottomPadding: CGFloat = 19
    }
}

private struct SwapAssetAvatarView: View {
    let left: MultichainTransactionDetailsModel.Asset
    let right: MultichainTransactionDetailsModel.Asset

    var body: some View {
        ZStack(alignment: .topLeading) {
            AssetAvatarView(
                imageSource: left.imageSource,
                size: .large,
                chainIconPosition: .leading
            )
            .frame(width: Layout.imageSize, height: Layout.imageSize)

            AssetAvatarView(
                imageSource: right.imageSource,
                size: .large,
                chainIconPosition: .trailing
            )
            .frame(width: Layout.imageSize, height: Layout.imageSize)
            .offset(x: Layout.secondImageOffset)
        }
        .frame(
            width: Layout.width,
            height: Layout.height,
            alignment: .topLeading
        )
    }

    enum Layout {
        static let imageSize: CGFloat = 72
        static let secondImageOffset: CGFloat = 64
        static let width: CGFloat = 136
        static let height: CGFloat = 80
    }
}
