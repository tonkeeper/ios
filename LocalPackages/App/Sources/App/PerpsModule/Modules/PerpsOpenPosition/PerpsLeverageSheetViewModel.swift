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
    private let reviewLiquidation: (Double) -> Double?

    init(
        context: PerpsLeverageSheetContext,
        reviewLiquidation: @escaping (Double) -> Double?
    ) {
        self.context = context
        self.reviewLiquidation = reviewLiquidation
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
        liquidationText = reviewLiquidation(leverage).map { PerpsFormatting.usd($0) }
    }
}
