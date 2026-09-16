import Foundation
import KeeperCore
import SwiftUI

@MainActor
final class PerpsLeverageSheetViewModel: ObservableObject {
    @Published var leverage: Double
    @Published private(set) var liquidationText: String?

    let bounds: PerpsLeverageBounds

    var onApply: ((Double) -> Void)?
    var onClose: (() -> Void)?

    private let context: PerpsLeverageSheetContext
    private let service: PerpsTradingService

    init(context: PerpsLeverageSheetContext, service: PerpsTradingService) {
        self.context = context
        self.service = service
        self.bounds = context.bounds
        self.leverage = min(max(context.current, context.bounds.min), context.bounds.max)
        recomputeLiquidation()
    }

    var leverageText: String {
        PerpsFormatting.leverage(leverage)
    }

    var minLeverage: Int {
        Int(bounds.min)
    }

    var maxLeverage: Int {
        Int(bounds.max)
    }

    func setLeverage(_ value: Double) {
        leverage = min(max(value.rounded(), bounds.min), bounds.max)
        recomputeLiquidation()
    }

    func setMin() {
        setLeverage(bounds.min)
    }

    func setMax() {
        setLeverage(bounds.max)
    }

    func apply() {
        onApply?(leverage)
    }

    private func recomputeLiquidation() {
        guard let maintenanceFraction = context.maintenanceFraction, context.markPrice > 0 else {
            liquidationText = nil
            return
        }
        let margin = context.marginUsd > 0 ? context.marginUsd : 1
        let preview = service.previewLiquidation(
            side: context.side,
            marginUsd: margin,
            leverage: leverage,
            openingFeeRate: context.openingFeeRate,
            entryPrice: context.markPrice,
            markPrice: context.markPrice,
            maintenanceFraction: maintenanceFraction
        )
        liquidationText = preview.price.map { PerpsFormatting.usd($0) }
    }
}
