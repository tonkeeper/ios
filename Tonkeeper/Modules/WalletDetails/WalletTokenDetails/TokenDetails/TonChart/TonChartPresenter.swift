//
//  TonChartTonChartPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import UIKit
import TKUIKit
import TKChart
import WalletCoreKeeper
import WalletCoreCore

final class TonChartPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TonChartViewInput?
  weak var output: TonChartModuleOutput?
  
  // MARK: - Dependencies
  
  private let walletProvider: WalletProvider
  private let chartController: ChartController
  
  // MARK: - State
  
  private var selectedPeriod: WalletCoreKeeper.Period = .week
  private var reloadTask: Task<Void, Error>?
  
  private var currency: WalletCoreCore.Currency {
    (try? walletProvider.activeWallet.currency) ?? .USD
  }
  
  init(walletProvider: WalletProvider,
       chartController: ChartController) {
    self.walletProvider = walletProvider
    self.chartController = chartController
    
    walletProvider.addObserver(self)
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
    selectedPeriod = WalletCoreKeeper.Period.allCases[index]
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
    let buttons = WalletCoreKeeper.Period.allCases.map {
      TKButton.Model(title: .string($0.title))
    }
    let model = TonChartButtonsView.Model(buttons: buttons)
    viewInput?.updateButtons(with: model)
    viewInput?.selectButton(at: WalletCoreKeeper.Period.allCases.firstIndex(of: selectedPeriod) ?? 0)
  }
  
  func reloadChartDataAndHeader() {
    Task {
      do {
        try await reloadChartData()
        await showUnselectedHeader()
      } catch {
        await MainActor.run {
          showError(error: error)
          showErrorHeader()
        }
      }
    }
  }
  
  func reloadChartData() async throws {
    let coordinates = try await chartController.getChartData(
      period: selectedPeriod, 
      currency: currency
    )
    let chartData = prepareChartData(coordinates: coordinates, period: selectedPeriod)
    await MainActor.run {
      viewInput?.updateChart(with: chartData)
    }
  }
  
  func showUnselectedHeader() async {
    guard await !chartController.coordinates.isEmpty else { return }
    let pointInformation = await chartController.getInformation(
      at: chartController.coordinates.count - 1,
      period: selectedPeriod,
      currency: currency
    )
    let headerModel = prepareHeaderModel(pointInformation: pointInformation, date: "Price")
    await MainActor.run {
      viewInput?.updateHeader(with: headerModel)
    }
  }
  
  func showSelectedHeader(index: Int) async {
    let pointInformation = await chartController.getInformation(
      at: index,
      period: selectedPeriod,
      currency: currency
    )
    let headerModel = prepareHeaderModel(pointInformation: pointInformation, date: pointInformation.date)
    await MainActor.run {
      viewInput?.updateHeader(with: headerModel)
    }
  }

  func prepareChartData(coordinates: [WalletCoreKeeper.Coordinate],
                        period: WalletCoreKeeper.Period) -> TKLineChartView.Data {
    let mode: TKLineChartView.Mode
    switch period {
    case .hour:
      mode = .stepped
    default:
      mode = .linear
    }
    
    return TKLineChartView.Data(coordinates: coordinates, mode: mode)
  }

  func prepareHeaderModel(pointInformation: ChartPointInformationViewModel,
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

  func showError(error: Error) {
    let title: String
    let subtitle: String
    if error.isNoConnectionError {
      title = "No internet connection"
      subtitle = "Please check your connection and try again."
    } else {
      title = "Failed to load chart data"
      subtitle = "Please try again"
    }
    let model = TonChartErrorView.Model(
      title: title,
      subtitle: subtitle
    )
    viewInput?.showError(with: model)
  }

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

extension TonChartPresenter: WalletProviderObserver {
  func didUpdateActiveWallet() {
    reload()
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

extension WalletCoreKeeper.Coordinate: TKChart.Coordinate {}
