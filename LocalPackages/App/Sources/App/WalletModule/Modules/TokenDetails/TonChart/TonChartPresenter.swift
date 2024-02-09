import UIKit
import TKUIKitLegacy
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
    reloadChartDataAndHeader()
  }
  
  func didSelectButton(at index: Int) {
    viewInput?.selectButton(at: index)
    selectedPeriod = Period.allCases[index]
    reloadChartDataAndHeader()
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
}

// MARK: - TonChartModuleInput

extension TonChartPresenter: TonChartModuleInput {
  func reload() {
    Task {
      reloadChartDataAndHeader()
    }
  }
}

// MARK: - Private

private extension TonChartPresenter {
  func setupButtons() {
    let buttons: [TonChartButtonsView.Model.Button] = KeeperCore.Period
      .allCases
      .enumerated()
      .map { index, period in
        TonChartButtonsView.Model.Button(
          model: TonChartButton.Model(
            title: period.title
          )) { [weak self] in
            self?.viewInput?.selectButton(at: index)
            self?.selectedPeriod = KeeperCore.Period.allCases[index]
            self?.reloadChartDataAndHeader()
          }
      }
    let model = TonChartButtonsView.Model(buttons: buttons)
    viewInput?.updateButtons(with: model)
    viewInput?.selectButton(at: KeeperCore.Period.allCases.firstIndex(of: selectedPeriod) ?? 0)
  }
  
  func reloadChartDataAndHeader() {
    Task {
      do {
        try await reloadChartData()
        await showUnselectedHeader()
      } catch {
        await showError(error: error)
        await showErrorHeader()
      }
    }
  }
  
  func reloadChartData() async throws {
    let coordinates = try await chartController.getChartData(
      period: selectedPeriod
    )
    let chartData = prepareChartData(coordinates: coordinates, period: selectedPeriod)
    await MainActor.run {
      viewInput?.updateChart(with: chartData)
    }
  }
  
  @MainActor
  func showUnselectedHeader() {
    guard !chartController.coordinates.isEmpty else { return }
    let pointInformation = chartController.getInformation(
      at: chartController.coordinates.count - 1,
      period: selectedPeriod
    )
    let headerModel = prepareHeaderModel(pointInformation: pointInformation, date: "Price")
    viewInput?.updateHeader(with: headerModel)
  }
  
  @MainActor
  func showSelectedHeader(index: Int) {
    let pointInformation = chartController.getInformation(
      at: index,
      period: selectedPeriod
    )
    let headerModel = prepareHeaderModel(pointInformation: pointInformation, date: pointInformation.date)
    viewInput?.updateHeader(with: headerModel)
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
    let amount = pointInformation.amount.attributed(
      with: .amountTextStyle,
      color: .Text.primary
    )

    let date = date.attributed(
      with: .otherTextStyle,
      color: .Text.secondary
    )

    let diffColor: UIColor
    switch pointInformation.diff.direction {
    case .down: diffColor = .Accent.red
    case .none: diffColor = .Text.secondary
    case .up: diffColor = .Accent.green
    }

    let percentDiff = pointInformation
        .diff
        .percent
        .attributed(
          with: .otherTextStyle,
          color: diffColor)
    let fiatDiff = pointInformation
        .diff
        .fiat
        .attributed(
          with: .otherTextStyle,
          color: diffColor.withAlphaComponent(0.44))

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
    let amount = "0".attributed(
      with: .amountTextStyle,
      color: .Text.primary
    )

    let date = "Price".attributed(
      with: .otherTextStyle,
      color: .Text.secondary
    )

    let percentDiff = "0%"
        .attributed(
          with: .otherTextStyle,
          color: .Text.secondary)
    let fiatDiff = "0,00"
        .attributed(
          with: .otherTextStyle,
          color: .Text.secondary.withAlphaComponent(0.44))


    let headerModel = TonChartHeaderView.Model.init(amount: amount, percentDiff: percentDiff, fiatDiff: fiatDiff, date: date)
    viewInput?.updateHeader(with: headerModel)
  }
}

private extension TextStyle {
  static var amountTextStyle: TextStyle {
    TextStyle(font: .monospacedSystemFont(ofSize: 20, weight: .bold),
                    lineHeight: 28)
  }
  
  static var otherTextStyle: TextStyle {
    TextStyle(font: .monospacedSystemFont(ofSize: 14, weight: .medium),
                    lineHeight: 20)
  }
}

extension KeeperCore.Coordinate: TKChart.Coordinate {}
