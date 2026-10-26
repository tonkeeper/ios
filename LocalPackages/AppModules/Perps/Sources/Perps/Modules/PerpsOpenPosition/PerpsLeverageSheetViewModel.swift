import Combine
import Foundation
import PerpsModels
import SwiftUI

@MainActor
final class PerpsLeverageSheetViewModel: ObservableObject, PerpsLeverageSheetViewModeling {
    @Published var leverage: Double
    @Published private(set) var liquidationText: String?

    let bounds: PerpsLeverageBounds

    var onApply: ((Double) -> Void)?
    var onClose: (() -> Void)?

    private let context: PerpsLeverageSheetContext
    private let reviewLiquidation: (Double) -> Double?
    private let format: PerpsFormatting
    private var reviewerLoadedCancellable: AnyCancellable?

    init(
        context: PerpsLeverageSheetContext,
        format: PerpsFormatting,
        reviewLiquidation: @escaping (Double) -> Double?,
        reviewerLoaded: AnyPublisher<Void, Never>
    ) {
        self.context = context
        self.format = format
        self.reviewLiquidation = reviewLiquidation
        self.bounds = context.bounds
        self.leverage = min(max(context.current, context.bounds.min), context.bounds.max)
        recomputeLiquidation()
        reviewerLoadedCancellable = reviewerLoaded.sink { [weak self] in self?.recomputeLiquidation() }
    }

    var leverageText: String {
        format.leverage(leverage)
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
        liquidationText = reviewLiquidation(leverage).map { format.usd($0) }
    }
}
