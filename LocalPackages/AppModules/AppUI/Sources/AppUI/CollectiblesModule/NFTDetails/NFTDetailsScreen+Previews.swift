import SwiftUI
import TKUIKit
import UIKit

@available(iOS 17.0, *)
#Preview("Collectible") {
    NFTDetailsScreen(
        state: .previewCollectible,
        onClose: {},
        onCopy: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("On Sale") {
    NFTDetailsScreen(
        state: .previewOnSale,
        onClose: {},
        onCopy: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Unverified") {
    NFTDetailsScreen(
        state: .previewUnverified,
        onClose: {},
        onCopy: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Sections", traits: .sizeThatFitsLayout) {
    VStack(spacing: 0) {
        NFTDetailsPropertiesView(properties: .preview)
        NFTDetailsListView(
            details: NFTDetailsScreenState.previewDetails,
            onCopy: { _ in }
        )
    }
    .frame(width: 390)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

private extension NFTDetailsScreenState.Properties {
    static let preview = NFTDetailsScreenState.Properties(
        title: "Properties",
        properties: [
            Property(id: "background", title: "Background", value: "Deep blue"),
            Property(id: "eyes", title: "Eyes", value: "Amber"),
            Property(id: "rarity", title: "Rarity", value: "Legendary"),
        ]
    )
}

private extension NFTDetailsScreenState {
    static let previewCollectible = NFTDetailsScreenState(
        header: Header(
            title: "Mirra Yui",
            leftButton: .swipeDown,
            menuItems: previewMenuItems
        ),
        information: Information(
            imageSource: .image(previewArtwork()),
            name: "Mirra Yui",
            collectionName: "Annihilation",
            isCollectionVerified: true,
            description: "A hand drawn collectible from the Annihilation series, minted on TON. Holders get access to the community channel and future drops.",
            collectionSection: Information.CollectionSection(
                title: "About collection",
                description: "Annihilation is a collection of 5000 hand drawn characters living on the TON blockchain."
            ),
            moreTitle: "More"
        ),
        buttons: [
            Button(
                id: "transfer",
                title: "Transfer",
                appearance: .primary,
                action: {}
            ),
            Button(
                id: "programmatic",
                title: "Manage",
                appearance: .primaryGreen,
                icon: ButtonView.Icon(
                    image: .TKUIKit.Icons.Size16.linkSmall,
                    alignment: .trailing
                ),
                action: {}
            ),
        ],
        properties: .preview,
        details: previewDetails
    )

    static let previewOnSale = NFTDetailsScreenState(
        header: Header(
            title: "Mirra Yui",
            leftButton: .swipeDown,
            menuItems: previewMenuItems
        ),
        information: Information(
            imageSource: .image(previewArtwork()),
            isOnSale: true,
            name: "Mirra Yui",
            collectionName: "Annihilation",
            isCollectionVerified: true,
            description: "A hand drawn collectible from the Annihilation series, minted on TON. Holders get access to the community channel and future drops.",
            collectionSection: Information.CollectionSection(
                title: "About collection",
                description: "Annihilation is a collection of 5000 hand drawn characters living on the TON blockchain."
            ),
            moreTitle: "More"
        ),
        buttons: [
            Button(
                id: "transfer",
                title: "Transfer",
                appearance: .primary,
                isEnabled: false,
                description: "NFT is on sale at the marketplace now. For transfer, you should remove it from sale first.",
                action: {}
            ),
        ],
        properties: .preview,
        details: previewDetails
    )

    static let previewUnverified = NFTDetailsScreenState(
        header: Header(
            title: "Free Airdrop",
            leftButton: .back,
            caption: Header.Caption(
                title: "Unverified NFT",
                color: .accentOrange,
                action: {}
            ),
            menuItems: previewMenuItems
        ),
        spamActions: SpamActions(
            reportSpamTitle: "Report spam",
            notSpamTitle: "Not spam",
            onReportSpam: {},
            onNotSpam: {}
        ),
        information: Information(
            imageSource: .image(previewArtwork()),
            name: "Free Airdrop",
            collectionName: "Single NFT",
            isCollectionVerified: false,
            description: "Claim your reward at the link inside.",
            moreTitle: "More"
        ),
        buttons: [
            Button(
                id: "transfer",
                title: "Transfer",
                appearance: .primary,
                action: {}
            ),
        ],
        details: previewDetails
    )

    static var previewDetails: Details {
        Details(
            title: "Details",
            explorerButtonTitle: "View in explorer",
            items: [
                Details.Item(
                    id: "owner",
                    title: "Owner",
                    value: "UQCONm…x7oLU",
                    copyValue: "UQCONmollH5o17uo1YWTU8lS0lS3ZFAM421u531UK4x7oLU"
                ),
                Details.Item(
                    id: "contract",
                    title: "Contract address",
                    value: "EQAOQd…M9OJa",
                    copyValue: "EQAOQdwdw8kGftJCSFgOErM1mBjYPe4DBPq8-AhF6vr9si5N"
                ),
            ],
            onOpenExplorer: {}
        )
    }

    static var previewMenuItems: [TKPopupMenuItem] {
        [
            TKPopupMenuItem(
                title: "Hide NFT",
                icon: .TKUIKit.Icons.Size16.eyeDisable,
                selectionHandler: {}
            ),
            TKPopupMenuItem(
                title: "View on Tonviewer",
                icon: .TKUIKit.Icons.Size16.globe,
                selectionHandler: {}
            ),
        ]
    }
}

private func previewArtwork() -> UIImage {
    let size = CGSize(width: 360, height: 360)
    return UIGraphicsImageRenderer(size: size).image { context in
        UIColor(red: 0.16, green: 0.22, blue: 0.33, alpha: 1).setFill()
        context.fill(CGRect(origin: .zero, size: size))
        UIColor(red: 0.55, green: 0.68, blue: 0.85, alpha: 1).setFill()
        context.cgContext.fillEllipse(
            in: CGRect(x: 90, y: 90, width: 180, height: 180)
        )
    }
}
