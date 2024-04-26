import UIKit
import TKUIKit
import TKChart
import KeeperCore

final class TonChartPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TonChartViewInput?
  
  // MARK: - Dependencies
  
  private let chartController: ChartController
  
  // MARK: - State
  
  private var selectedPeriod: Period = .week
  private var reloadTask: Task<Void, Error>?
  
  init(chartController: ChartController) {
    self.chartController = chartController
  }
}

// MARK: - TonChartPresenterIntput

extension TonChartPresenter: TonChartPresenterInput {
  func viewDidLoad() {
    setupButtons()
    Task {
      chartController.didUpdateChartData = { [weak self] in
        guard let self else { return }
        Task { await self.reloadChartDataAndHeader() }
      }
      await chartController.start()
      await reloadChartDataAndHeader()
      
      startChartReloadTimer()
    }
  }
  
  func didSelectButton(at index: Int) {
    viewInput?.selectButton(at: index)
    selectedPeriod = Period.allCases[index]
    Task {
      await reloadChartDataAndHeader()
    }
  }
  
  func didSelectChartValue(at index: Int) {
    Task {
      await showSelectedHeader(index: index)
    }
  }
  
  func didDeselectChartValue() {
    Task {
      await showUnselectedHeader()
    }
  }
  
  func startChartReloadTimer() {
    reloadTask = Task {
      try? await Task.sleep(nanoseconds: 60_000_000_000)
      reload()
      startChartReloadTimer()
    }
  }
}

// MARK: - TonChartModuleInput

extension TonChartPresenter: TonChartModuleInput {
  func reload() {
    Task {
      await reloadChartDataAndHeader()
    }
  }
}

// MARK: - Private

private extension TonChartPresenter {
  func setupButtons() {
    let buttons: [TKButton.Configuration] = KeeperCore.Period.allCases.enumerated().map { index, period in
      var configuration = TKButton.Configuration.chartButtonConfiguration
      configuration.content.title = .plainString(period.title)
      configuration.action = { [weak self] in
        guard let self else { return }
        self.viewInput?.selectButton(at: index)
        self.selectedPeriod = KeeperCore.Period.allCases[index]
        Task {
          await self.reloadChartDataAndHeader()
        }
      }
      return configuration
    }
    
    let model = TonChartButtonsView.Model(buttons: buttons)
    viewInput?.updateButtons(with: model)
    viewInput?.selectButton(at: KeeperCore.Period.allCases.firstIndex(of: selectedPeriod) ?? 0)
  }
  
  func reloadChartDataAndHeader() async {
    do {
      try await reloadChartData()
      await showUnselectedHeader()
    } catch {
      await showError(error: error)
      await showErrorHeader()
    }
  }
  
  func reloadChartData() async throws {
//    let coordinates = try await chartController.getChartData(
//      period: selectedPeriod
//    )
//    let chartData = prepareChartData(coordinates: coordinates, period: selectedPeriod)
//    await MainActor.run {
//      viewInput?.updateChart(with: chartData)
//    }
  }
  
  func showUnselectedHeader() async {
    guard !chartController.coordinates.isEmpty else { return }
    let pointInformation = await chartController.getInformation(
      at: chartController.coordinates.count - 1,
      period: selectedPeriod
    )
    let headerModel = prepareHeaderModel(pointInformation: pointInformation, date: "Price")
    await MainActor.run {
      viewInput?.updateHeader(with: headerModel)
    }
  }
  
  func showSelectedHeader(index: Int) async {
    let pointInformation = await chartController.getInformation(
      at: index,
      period: selectedPeriod
    )
    let headerModel = prepareHeaderModel(pointInformation: pointInformation, date: pointInformation.date)
    await MainActor.run {
      viewInput?.updateHeader(with: headerModel)
    }
  }

  func prepareChartData(coordinates: [TKChart.Coordinate],
                        period: Period) -> TKLineChartView.Data {
    let mode: TKLineChartView.Mode
    switch period {
    case .hour:
      mode = .stepped
    default:
      mode = .linear
    }
    
    return TKLineChartView.Data(coordinates: coordinates, mode: mode)
  }

  func prepareHeaderModel(pointInformation: ChartPointInformationModel,
                          date: String) -> TonChartHeaderView.Model {
    let amount = pointInformation.amount.withTextStyle(
      .amountTextStyle,
      color: .Text.primary)
    
    let date = date.withTextStyle(
      .otherTextStyle,
      color: .Text.secondary
    )
    
    let diffColor: UIColor
    switch pointInformation.diff.direction {
    case .down: diffColor = .Accent.red
    case .none: diffColor = .Text.secondary
    case .up: diffColor = .Accent.green
    }

    let percentDiff = pointInformation
      .diff.percent.withTextStyle(.otherTextStyle, color: diffColor)
    
    let fiatDiff = pointInformation
      .diff.fiat.withTextStyle(.otherTextStyle, color: diffColor.withAlphaComponent(0.44))
    
    return .init(amount: amount, percentDiff: percentDiff, fiatDiff: fiatDiff, date: date)
  }

  @MainActor
  func showError(error: Error) {
    let title = "Failed to load chart data"
    let subtitle = "Please try again"
    let model = TonChartErrorView.Model(
      title: title,
      subtitle: subtitle
    )
    viewInput?.showError(with: model)
  }

  @MainActor
  func showErrorHeader() {
    let amount = "0".withTextStyle(
      .amountTextStyle,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    
    let date = "Price".withTextStyle(
      .otherTextStyle,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )

    let percentDiff = "0%".withTextStyle(
      .otherTextStyle,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    
    let fiatDiff = "0,00".withTextStyle(
      .otherTextStyle,
      color: .Text.secondary.withAlphaComponent(0.44),
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
  
    let headerModel = TonChartHeaderView.Model.init(amount: amount, percentDiff: percentDiff, fiatDiff: fiatDiff, date: date)
    viewInput?.updateHeader(with: headerModel)
  }
}

private extension TKTextStyle {
  static var amountTextStyle: TKTextStyle {
    TKTextStyle(
      font: .monospacedSystemFont(ofSize: 20, weight: .bold),
      lineHeight: 28
    )
  }
  
  static var otherTextStyle: TKTextStyle {
    TKTextStyle(
      font: .monospacedSystemFont(ofSize: 14, weight: .bold),
      lineHeight: 20
    )
  }
}

extension KeeperCore.Coordinate: TKChart.Coordinate {}

private extension TKButton.Configuration {
  static var chartButtonConfiguration: TKButton.Configuration {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .small
    )
    configuration.backgroundColors = [.normal: .clear,
                                      .selected: TKActionButtonCategory.secondary.backgroundColor]
    configuration.textColor = .Button.primaryForeground
    configuration.contentAlpha = [.normal: 1,
                                  .highlighted: 0.48]
    return configuration
  }
}
