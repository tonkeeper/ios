import Foundation
import UIKit
import KeeperCore
import TKChart
import TKCore
import TKLocalize
import TKUIKit

final class LPTokenChartViewModel: ChartViewModel, ChartModuleOutput {
  // MARK: - ChartViewModel
  
  var didUpdateHeader: ((ChartHeaderView.Configuration) -> Void)?
  var didUpdateChartData: ((TKLineChartFullView.Model) -> Void)?
  var didUpdateButtons: ((ChartButtonsView.Model) -> Void)?
  var didFailedUpdateChartData: ((ChartErrorView.Model) -> Void)?
  
  func viewDidLoad() {
    setupControllerBindings()
    
    Task {
      await updateButtons()
      await controller.start()
    }
  }
  
  func didSelectChartPoint(at index: Int) {
    controller.selectChartPoint(index: index)
  }
  
  func didDeselectChartPoint() { 
    controller.selectChartPoint(index: .zero)
  }
  
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"
    return formatter
  }()
  
  // MARK: - Dependencies
  
  private let controller: LPTokenChartController
  private let amountFormatter: AmountFormatter
  
  // MARK: - Init
  
  init(controller: LPTokenChartController, amountFormatter: AmountFormatter) {
    self.controller = controller
    self.amountFormatter = amountFormatter
  }
}

// MARK: - Private methods

private extension LPTokenChartViewModel {
  func setupControllerBindings() {
    controller.didUpdateProfits = { [weak self] profits in
      guard let self else { return }
      
      let chartModel = self.createChartModel(profits: profits)
      
      didUpdateChartData?(chartModel)
    }
    
    controller.didUpdateErrorState = { [weak self] in
      let model = ChartErrorView.Model(
        title: .errorTitle,
        subtitle: .errorSubtitle
      )
      
      self?.didFailedUpdateChartData?(model)
      self?.didUpdateHeader?(.empty)
    }
    
    controller.diUpdateCurrentBalance = { [weak self] value in
      guard let self else { return }
      
      let token = self.controller.token
      let formatted =  amountFormatter.formatAmount(
        value,
        fractionDigits: token.fractionDigits,
        maximumFractionDigits: token.fractionDigits,
        symbol: token.symbol
      )
      didUpdateHeader?(.init(balance: formatted))
    }
  }
  
  func updateButtons() async  {
    let buttonModels = ["History", "Forecast"].enumerated().map { index, segment in
      ChartButtonsView.Model.Button(title: segment, isSelected: index == 0, tapAction: {
        print("Did select item")
      })
    }
    
    let model = ChartButtonsView.Model(buttons: buttonModels)
    
    await MainActor.run {
      didUpdateButtons?(model)
    }
  }
  
  func createChartModel(profits: [LPTokenChartController.ProfitByMonth]) -> TKLineChartFullView.Model {
    let token = controller.token
    let max = profits.last?.amount ?? .zero
    let min = profits.first?.amount ?? .zero
    let coordinates = controller.mapProfitsByMonth(profits)
    
    let maxValue = amountFormatter.formatAmount(max, fractionDigits: token.fractionDigits, maximumFractionDigits: token.fractionDigits, symbol: token.symbol)
    let minValue = amountFormatter.formatAmount(min, fractionDigits: token.fractionDigits, maximumFractionDigits: token.fractionDigits, symbol: token.symbol)
    
    let chartData = TKLineChartView.ChartData(mode: .linear, coordinates: coordinates, color: .Accent.green)
    return .init(
      chartData: chartData,
      maximumValue: maxValue,
      minimumValue: minValue,
      xAxisLeftValue: getMonthName(byAddingMonths: 1),
      xAxisMiddleValue: getMonthName(byAddingMonths: 6)
    )
  }
  
  func getMonthName(byAddingMonths months: Int) -> String {
    if let targetDate = Calendar.current.date(byAdding: .month, value: months, to: Date()) {
      return dateFormatter.string(from: targetDate)
    }
    
    return ""
  }
}

private extension ChartHeaderView.Configuration {
  static let empty = Self(price: "", diff: .init(diff: "", priceDiff: "", direction: .none), date: "")
  
  init(balance: String) {
    self.init(price: balance, diff: .init(diff: "Balance", priceDiff: "", direction: .none), date: "")
  }
}


private extension String {
  static let errorTitle = "Failed to load chart data"
  static let errorSubtitle = "Please try again"
}
