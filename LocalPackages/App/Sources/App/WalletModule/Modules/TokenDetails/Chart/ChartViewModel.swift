import Foundation
import KeeperCore
import TKChart
import TKCore

protocol ChartModuleOutput: AnyObject {}

protocol ChartViewModel: AnyObject {
  var didUpdateHeader: ((ChartHeaderView.Configuration) -> Void)? { get set }
  var didUpdateChartData: ((TKLineChartFullView.Model) -> Void)? { get set }
  var didUpdateButtons: ((ChartButtonsView.Model) -> Void)? { get set }
  var didFailedUpdateChartData: ((ChartErrorView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectChartPoint(at index: Int)
  func didDeselectChartPoint()
  func didUpdateWidth(_ width: CGFloat)
}

final class ChartViewModelImplementation: ChartViewModel, ChartModuleOutput {
  
  // MARK: - ChartModuleOutput
  
  // MARK: - ChartViewModel
  
  var didUpdateHeader: ((ChartHeaderView.Configuration) -> Void)?
  var didUpdateChartData: ((TKLineChartFullView.Model) -> Void)?
  var didUpdateButtons: ((ChartButtonsView.Model) -> Void)?
  var didFailedUpdateChartData: ((ChartErrorView.Model) -> Void)?
  
  func viewDidLoad() {
    Task {
      await updateButtons()
      await updateChart()
    }
  }
  
  func didSelectChartPoint(at index: Int) {
    Task {
      let currency = await currencyStore.getActiveCurrency()
      let period = await state.period
      let coordinates = await state.coordinates
      let pointModel = preparePointModel(
        index: index,
        coordinates: coordinates,
        currency: currency,
        period: period
      )
      await MainActor.run {
        didUpdateHeader?(pointModel)
      }
    }
  }
  
  func didDeselectChartPoint() {
    Task {
      let currency = await currencyStore.getActiveCurrency()
      let period = await state.period
      let coordinates = await state.coordinates
      let pointModel = prepareLastPointModel(
        coordinates: coordinates,
        currency: currency,
        period: period
      )
      await MainActor.run {
        didUpdateHeader?(pointModel)
      }
    }
  }
  
  func didUpdateWidth(_ width: CGFloat) {
    
  }
  
  actor State {
    var period: Period = .month
    var coordinates = [KeeperCore.Coordinate]()
    
    func setPeriod(_ period: Period) {
      self.period = period
    }
    
    func setCoordinates(_ coordinates: [KeeperCore.Coordinate]) {
      self.coordinates = coordinates
    }
  }
  
  // MARK: - State
  
  private var state = State()
  
  // MARK: - Dependencies
  
  private let chartController: ChartV2Controller
  private let currencyStore: CurrencyStore
  private let chartFormatter: ChartFormatter
  
  // MARK: - Init
  
  init(chartController: ChartV2Controller,
       currencyStore: CurrencyStore,
       chartFormatter: ChartFormatter) {
    self.chartController = chartController
    self.currencyStore = currencyStore
    self.chartFormatter = chartFormatter
  }
}

private extension ChartViewModelImplementation {
  func didSelectPeriodButtonAt(index: Int) {
    Task {
      await state.setPeriod(Period.allCases[index])
      await updateChart()
    }
  }
  
  func updateButtons() async {
    let selectedPeriod = await state.period
    let buttonModels = Period.allCases.enumerated().map { index, period in
      ChartButtonsView.Model.Button(
        title: period.title,
        isSelected: period == selectedPeriod) { [weak self] in
          self?.didSelectPeriodButtonAt(index: index)
          
        }
    }
    let model = ChartButtonsView.Model(
      buttons: buttonModels
    )
    await MainActor.run {
      didUpdateButtons?(model)
    }
  }
  
  func updateChart() async {
    let currency = await currencyStore.getActiveCurrency()
    let period = await state.period
    let cachedCoordinates = chartController.getCachedChartData(period: period, currency: currency)
    await state.setCoordinates(cachedCoordinates)
    let cachedModel = prepareChartModel(coordinates: cachedCoordinates, period: period, currency: currency)
    let lastPointModel = prepareLastPointModel(coordinates: cachedCoordinates, currency: currency, period: period)
    await MainActor.run {
      didUpdateChartData?(cachedModel)
      didUpdateHeader?(lastPointModel)
    }
    
    do {
      let loadedCoordinates = try await chartController.loadChartData(period: period, currency: currency)
      await state.setCoordinates(loadedCoordinates)
      let loadedModel = prepareChartModel(coordinates: loadedCoordinates, period: period, currency: currency)
      let lastPointModel = prepareLastPointModel(coordinates: cachedCoordinates, currency: currency, period: period)
      await MainActor.run {
        didUpdateChartData?(loadedModel)
        didUpdateHeader?(lastPointModel)
      }
    } catch {
      let title = "Failed to load chart data"
      let subtitle = "Please try again"
      let model = ChartErrorView.Model(
        title: title,
        subtitle: subtitle
      )
      await MainActor.run {
        didFailedUpdateChartData?(model)
        didUpdateHeader?(emptyHeaderModel())
      }
    }
  }
  
  func prepareChartModel(coordinates: [KeeperCore.Coordinate], period: Period, currency: Currency) -> TKLineChartFullView.Model {
    let mode: TKLineChartView.ChartMode
    switch period {
    case .hour:
      mode = .stepped
    default:
      mode = .linear
    }
    let chartData = TKLineChartView.ChartData(
      mode: mode,
      coordinates: coordinates
    )
    
    let values = coordinates.map { $0.y }
    let maximumValue = chartFormatter.mapMaxMinValue(value: values.max() ?? 0, currency: currency)
    let minimumValue = chartFormatter.mapMaxMinValue(value: values.min() ?? 0, currency: currency)
    
    var xAxisLeftValue = ""
    var xAxisMiddleValue = ""
    
    let leftValueIndex = coordinates.count/10
    if coordinates.count > leftValueIndex {
      xAxisLeftValue = chartFormatter.formatXAxis(timeInterval: coordinates[leftValueIndex].x, period: period) ?? ""
    }
    let middleValueIndex = coordinates.count/2
    if coordinates.count > leftValueIndex {
      xAxisMiddleValue = chartFormatter.formatXAxis(timeInterval: coordinates[middleValueIndex].x, period: period) ?? ""
    }
    
    return TKLineChartFullView.Model(
      chartData: chartData,
      maximumValue: maximumValue,
      minimumValue: minimumValue,
      xAxisLeftValue: xAxisLeftValue,
      xAxisMiddleValue: xAxisMiddleValue
    )
  }
  
  func preparePointModel(coordinate: KeeperCore.Coordinate, 
                         coordinates: [KeeperCore.Coordinate],
                         currency: Currency,
                         date: String) -> ChartHeaderView.Configuration {
    let calculatedDiff = calculateDiff(coordinates: coordinates, coordinate: coordinate)
    
    let price = chartFormatter.formatValue(coordinate: coordinate, currency: currency)
    let formattedDiff = chartFormatter.formatDiff(diff: calculatedDiff.diff)
    let formattedCurrencyDiff = chartFormatter.formatCurrencyDiff(diff: calculatedDiff.currencyDiff, currency: currency)
    
    let direction: ChartHeaderView.Configuration.Diff.Direction
    switch calculatedDiff.diff {
    case let x where x < 0:
      direction = .down
    case let x where x > 0:
      direction = .up
    default:
      direction = .none
    }
    
    let diff = ChartHeaderView.Configuration.Diff(
      diff: formattedDiff,
      priceDiff: formattedCurrencyDiff,
      direction: direction
    )
    return ChartHeaderView.Configuration(
      price: price,
      diff: diff,
      date: date
    )
  }
  
  func prepareLastPointModel(coordinates: [KeeperCore.Coordinate], currency: Currency, period: Period) -> ChartHeaderView.Configuration {
    guard let coordinate = coordinates.last else {
      return emptyHeaderModel()
    }
    return preparePointModel(coordinate: coordinate, coordinates: coordinates, currency: currency, date: "Price")
  }
  
  func preparePointModel(index: Int, 
                         coordinates: [KeeperCore.Coordinate],
                         currency: Currency, 
                         period: Period) -> ChartHeaderView.Configuration {
    guard index < coordinates.count else {
      return emptyHeaderModel()
    }
    let coordinate = coordinates[index]
    let date = chartFormatter.formatInformationTimeInterval(coordinate.x, period: period)
    return preparePointModel(coordinate: coordinate, coordinates: coordinates, currency: currency, date: date ?? "")
  }
  
  func calculateDiff(coordinates: [KeeperCore.Coordinate], coordinate: KeeperCore.Coordinate) -> (diff: Double, currencyDiff: Double) {
    guard let startCoordinate = coordinates.first else { return (0, 0) }
    let diff = (coordinate.y / startCoordinate.y - 1) * 100
    let currencyDiff = (coordinate.y - startCoordinate.y)
    return (diff, currencyDiff)
  }
  
  func emptyHeaderModel() -> ChartHeaderView.Configuration {
    ChartHeaderView.Configuration(
      price: "",
      diff: ChartHeaderView.Configuration.Diff(
        diff: "",
        priceDiff: "",
        direction: .none
      ),
      date: ""
    )
  }
}

extension KeeperCore.Coordinate: TKChart.Coordinate {}
