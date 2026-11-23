import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Default", traits: .fixedLayout(width: 390, height: 184)) {
    PredictionsSectionPreview(state: .cards(balance: nil, cards: [.btc, .eth, .gram]))
}

@available(iOS 17.0, *)
#Preview("Long title", traits: .fixedLayout(width: 390, height: 200)) {
    PredictionsSectionPreview(state: .cards(balance: nil, cards: [.gramLongTitle, .eth, .btc]))
}

@available(iOS 17.0, *)
#Preview("Loading", traits: .fixedLayout(width: 390, height: 184)) {
    PredictionsSectionPreview(state: .loading)
}

@available(iOS 17.0, *)
#Preview("Balance", traits: .fixedLayout(width: 390, height: 184)) {
    PredictionsSectionPreview(state: .cards(balance: "$78.00", cards: [.btc, .eth, .gram]))
}

@available(iOS 17.0, *)
#Preview("Positions", traits: .fixedLayout(width: 390, height: 184)) {
    PredictionsSectionPreview(state: .cards(balance: "$78.00", cards: [.btcPosition, .eth, .gram]))
}

@available(iOS 17.0, *)
#Preview("Market ended", traits: .fixedLayout(width: 390, height: 184)) {
    PredictionsSectionPreview(state: .cards(balance: "$90.20", cards: [.btcEnded, .eth, .gram]))
}

private struct PredictionsSectionPreview: View {
    let state: PredictionsSectionState

    var body: some View {
        PredictionsSectionView(
            state: state,
            onOpenPredictions: {},
            onSelectCard: { _ in },
            onSelectOutcome: { _, _ in }
        )
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
    }
}

private extension PredictionCardViewData {
    static var btc: PredictionCardViewData {
        PredictionCardViewData(
            id: "btc",
            imageSource: .image(.TKUIKit.Icons.Size44.btcChain),
            title: "BTC $82 175.73",
            subtitle: .countdown("To beat $82 319.50", endsAt: Date(timeIntervalSinceNow: 46)),
            footer: .outcomes(yes: "Up 41%", no: "Down 59%")
        )
    }

    static var btcPosition: PredictionCardViewData {
        PredictionCardViewData(
            id: "btc",
            imageSource: .image(.TKUIKit.Icons.Size44.btcChain),
            title: "BTC $82 175.73",
            subtitle: .countdown("To beat $82 319.50", endsAt: Date(timeIntervalSinceNow: 46)),
            footer: .position(
                PredictionPositionViewData(
                    title: "Up",
                    titleColor: .accentGreen,
                    amount: "$12.20",
                    change: "+$2.20",
                    changeColor: .accentGreen
                )
            )
        )
    }

    static let btcEnded = PredictionCardViewData(
        id: "btc",
        imageSource: .image(.TKUIKit.Icons.Size44.btcChain),
        title: "BTC $82 341.10",
        subtitle: .text("Ended · Up won"),
        footer: .position(
            PredictionPositionViewData(
                title: "Won",
                titleColor: .accentGreen,
                amount: "$24.40",
                change: "+$12.20",
                changeColor: .accentGreen
            )
        )
    )

    static let eth = PredictionCardViewData(
        id: "eth",
        imageSource: .image(.TKUIKit.Icons.Size44.ethChain),
        title: "ETH above $3 000?",
        subtitle: .text("Yes · 6 Dec, 16:00"),
        footer: .outcomes(yes: "Yes 54%", no: "No 46%")
    )

    static let gram = PredictionCardViewData(
        id: "gram",
        imageSource: .image(.TKUIKit.Icons.Size44.currencyGram),
        title: "GRAM above $0.01?",
        subtitle: .text("31 Dec, 23:59"),
        footer: .outcomes(yes: "Yes 62%", no: "No 38%")
    )

    static let gramLongTitle = PredictionCardViewData(
        id: "gram-long",
        imageSource: .image(.TKUIKit.Icons.Size44.currencyGram),
        title: "Will GRAM close above $0.012 on 31 Dec 2026 at 23:59 UTC?",
        subtitle: .text("Volume $1 245 300 · Ends 31 Dec, 23:59"),
        footer: .outcomes(yes: "Yes 62%", no: "No 38%")
    )
}
