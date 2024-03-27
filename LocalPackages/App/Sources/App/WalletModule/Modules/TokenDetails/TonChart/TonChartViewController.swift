import UIKit
import TKUIKit
import TKChart

class TonChartViewController: GenericViewViewController<TonChartView> {

  // MARK: - Module

  private let presenter: TonChartPresenterInput

  // MARK: - Init

  init(presenter: TonChartPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
}

// MARK: - TonChartViewInput

extension TonChartViewController: TonChartViewInput {
  func updateButtons(with model: TonChartButtonsView.Model) {
    customView.buttonsView.configure(model: model)
  }
  
  func updateHeader(with model: TonChartHeaderView.Model) {
    customView.headerView.configure(model: model)
  }
  
  func selectButton(at index: Int) {
    customView.buttonsView.selectButton(at: index)
  }
  
  func updateChart(with data: TKLineChartView.Data) {
    customView.errorView.isHidden = true
    customView.chartView.isHidden = false
    customView.chartView.setData(data)
  }
  
  func showError(with model: TonChartErrorView.Model) {
    customView.errorView.isHidden = false
    customView.chartView.isHidden = true
    customView.errorView.configure(model: model)
  }
}

// MARK: - Private

private extension TonChartViewController {
  func setup() {
    customView.chartView.delegate = self
  }
}

extension TonChartViewController: TKLineChartViewDelegate {
  func chartViewDidDeselectValue(_ chartView: TKLineChartView) {
    presenter.didDeselectChartValue()
  }
  
  func chartView(_ chartView: TKLineChartView, didSelectValueAt index: Int) {
    presenter.didSelectChartValue(at: index)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }
}
