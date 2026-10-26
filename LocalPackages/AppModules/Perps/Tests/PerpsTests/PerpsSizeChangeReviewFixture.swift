import PerpsModels

enum PerpsSizeChangeReviewFixture {
    static func make(
        direction: PerpsSizeChangeDirection = .add,
        side: PerpsTradeSide = .long,
        leverage: Double? = 27,
        marginDeltaUsd: Double = 20,
        entryPrice: PerpsValueChange = PerpsValueChange(old: 66541.70, new: 66021.17),
        notionalUsd: PerpsValueChange = PerpsValueChange(old: 540, new: 1080),
        baseSize: PerpsValueChange = PerpsValueChange(old: 0.008, new: 0.0163),
        liquidationPrice: Double? = 64141.75,
        estimatedFeeUsd: Double? = 0.144
    ) -> PerpsSizeChangeReview {
        PerpsSizeChangeReview(
            symbol: "BTC",
            direction: direction,
            side: side,
            leverage: leverage,
            marginDeltaUsd: marginDeltaUsd,
            entryPrice: entryPrice,
            notionalUsd: notionalUsd,
            baseSize: baseSize,
            liquidationPrice: liquidationPrice.map { PerpsValueChange(old: $0, new: $0) },
            liquidationUnavailableReason: liquidationPrice == nil ? .missingMark : nil,
            estimatedFeeUsd: estimatedFeeUsd
        )
    }
}
