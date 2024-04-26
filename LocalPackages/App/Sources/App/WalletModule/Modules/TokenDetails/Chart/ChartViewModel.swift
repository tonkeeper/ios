import Foundation
import KeeperCore
import TKChart

protocol ChartModuleOutput: AnyObject {}

protocol ChartViewModel: AnyObject {
  var didUpdateHeader: ((ChartHeaderView.Configuration) -> Void)? { get set }
  var didUpdateChartData: ((TKLineChartView.Data) -> Void)? { get set }
  var didUpdateButtons: ((ChartButtonsView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class ChartViewModelImplementation: ChartViewModel, ChartModuleOutput {
  
  // MARK: - ChartModuleOutput
  
  // MARK: - ChartViewModel
  
  var didUpdateHeader: ((ChartHeaderView.Configuration) -> Void)?
  var didUpdateChartData: ((TKLineChartView.Data) -> Void)?
  var didUpdateButtons: ((ChartButtonsView.Model) -> Void)?
  
  func viewDidLoad() {
    chartController.didUpdatePeriodConfiguration = { [weak self] periodModel in
      guard let self else { return }
      let buttons = periodModel.periods.enumerated().map { index, period in
        ChartButtonsView.Model.Button(
          title: period.title,
          isSelected: period == periodModel.selectedPeriod) { [weak self] in
            self?.didSelectPeriodButtonAt(index: index)
            
          }
      }
      let buttonsModel = ChartButtonsView.Model(
        buttons: buttons
      )
      Task { @MainActor in
        self.didUpdateButtons?(buttonsModel)
      }
    }
    
    chartController.didUpdateChartData = { [weak self] model in
      guard let self else { return }
      switch model {
      case .success(let chartData):
        let mode: TKLineChartView.Mode
        switch chartData.period {
        case .hour:
          mode = .stepped
        default:
          mode = .linear
        }
        
        let chartViewData = TKLineChartView.Data(
          coordinates: chartData.coordinates,
          mode: mode
        )
        Task { @MainActor in
          self.didUpdateChartData?(chartViewData)
        }
      case .failure:
        break
      }
    }
    
    Task { await chartController.start() }
  }
  
  // MARK: - Dependencies
  
  private let chartController: ChartV2Controller
  
  // MARK: - Init
  
  init(chartController: ChartV2Controller) {
    self.chartController = chartController
  }
}

private extension ChartViewModelImplementation {
  func didSelectPeriodButtonAt(index: Int) {
    Task { await chartController.selectPeriodAt(index: index) }
  }
}
