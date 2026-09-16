import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Token") {
    detailsPreview(state: .previewToken)
}

@available(iOS 17.0, *)
#Preview("Collection") {
    detailsPreview(state: .previewCollection)
}

private func detailsPreview(state: PurchasesManagementDetailsViewState) -> some View {
    ZStack(alignment: .bottom) {
        TKColor.backgroundOverlayStrong
            .ignoresSafeArea()

        PurchasesManagementDetailsView(
            state: state,
            onCopy: { _ in }
        )
    }
    .tkPreviewTheme(.deepBlue)
}

private extension PurchasesManagementDetailsViewState {
    static let previewToken = PurchasesManagementDetailsViewState(
        title: "Token details",
        items: [
            Item(
                id: "tokenId",
                title: "Token ID",
                value: "EQCONm…x7oLU",
                accessory: .copy,
                copyValue: "EQCONmollH5o17uo1YWTU8lS0lS3ZFAM421u531UK4x7oLU"
            ),
        ],
        button: Button(
            title: "Hide token from wallet",
            action: {}
        )
    )

    static let previewCollection = PurchasesManagementDetailsViewState(
        title: "Collection details",
        items: [
            Item(
                id: "name",
                title: "Name",
                value: "Annihilation",
                accessory: .image(nil)
            ),
            Item(
                id: "collectionId",
                title: "Collection ID",
                value: "EQAOQd…M9OJa",
                accessory: .copy,
                copyValue: "EQAOQdwdw8kGftJCSFgOErM1mBjYPe4DBPq8-AhF6vr9si5N"
            ),
        ],
        button: Button(
            title: "Show collection in wallet",
            action: {}
        )
    )
}
