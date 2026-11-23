import AppUI
import Foundation
import TKUIKit

enum PredictionsMockSource {
    static func snapshots() -> AsyncThrowingStream<PredictionsSnapshot, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Task.sleep(nanoseconds: loadingDelay)
                    while true {
                        let (snapshot, nextChange) = phase(at: Date())
                        continuation.yield(snapshot)
                        try await sleep(until: nextChange)
                    }
                } catch {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static let loadingDelay: UInt64 = 1_000_000_000
    private static let endedDisplayDuration: TimeInterval = 3
    private static let roundDuration: TimeInterval = 5 * 60
    private static let positionRoundEnd = nextRoundEnd(after: Date())

    private static func phase(at date: Date) -> (PredictionsSnapshot, nextChange: Date) {
        if date < positionRoundEnd {
            return (.withPosition(endsAt: positionRoundEnd), positionRoundEnd)
        }
        let wonUntil = positionRoundEnd.addingTimeInterval(endedDisplayDuration)
        if date < wonUntil {
            return (.won, wonUntil)
        }
        let roundEnd = nextRoundEnd(after: date)
        return (.open(endsAt: roundEnd), roundEnd)
    }

    private static func nextRoundEnd(after date: Date) -> Date {
        Date(timeIntervalSince1970: ((date.timeIntervalSince1970 / roundDuration).rounded(.down) + 1) * roundDuration)
    }

    private static func sleep(until date: Date) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, date.timeIntervalSinceNow) * 1_000_000_000))
    }
}

private extension PredictionsSnapshot {
    static func withPosition(endsAt: Date) -> PredictionsSnapshot {
        PredictionsSnapshot(
            balance: "$78.00",
            cards: [
                .bitcoin(
                    title: "BTC $82 175.73",
                    subtitle: .countdown("To beat $82 319.50", endsAt: endsAt),
                    footer: .position(
                        PredictionPositionViewData(
                            title: "Up",
                            titleColor: .accentGreen,
                            amount: "$12.20",
                            change: "+$2.20",
                            changeColor: .accentGreen
                        )
                    )
                ),
                .eth,
                .gram,
            ]
        )
    }

    static let won = PredictionsSnapshot(
        balance: "$90.20",
        cards: [
            .bitcoin(
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
            ),
            .eth,
            .gram,
        ]
    )

    static func open(endsAt: Date) -> PredictionsSnapshot {
        PredictionsSnapshot(
            balance: "$90.20",
            cards: [
                .bitcoin(
                    title: "BTC $82 341.10",
                    subtitle: .countdown("To beat $82 341.10", endsAt: endsAt),
                    footer: .outcomes(yes: "Up 50%", no: "Down 50%")
                ),
                .eth,
                .gram,
            ]
        )
    }
}

private extension PredictionCardViewData {
    static func bitcoin(title: String, subtitle: Subtitle, footer: Footer) -> PredictionCardViewData {
        PredictionCardViewData(
            id: "btc-up-or-down-5m",
            imageSource: .image(.TKUIKit.Icons.Size44.btcChain),
            title: title,
            subtitle: subtitle,
            footer: footer
        )
    }

    static let eth = PredictionCardViewData(
        id: "eth-above-3000",
        imageSource: .image(.TKUIKit.Icons.Size44.ethChain),
        title: "ETH above $3 000?",
        subtitle: .text("6 Dec, 16:00"),
        footer: .outcomes(yes: "Yes 54%", no: "No 46%")
    )

    static let gram = PredictionCardViewData(
        id: "gram-above-0.01",
        imageSource: .image(.TKUIKit.Icons.Size44.currencyGram),
        title: "GRAM above $0.01?",
        subtitle: .text("31 Dec, 23:59"),
        footer: .outcomes(yes: "Yes 62%", no: "No 38%")
    )
}
