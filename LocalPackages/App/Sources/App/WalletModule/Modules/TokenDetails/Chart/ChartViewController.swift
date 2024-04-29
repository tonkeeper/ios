import UIKit
import TKUIKit
import TKChart

final class ChartViewController: UIViewController {
  private let viewModel: ChartViewModel
  
  override func loadView() {
    view = ChartView()
  }
  
  var customView: ChartView {
    view as! ChartView
  }
  
  init(viewModel: ChartViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    setupViewEvents()
    
    viewModel.viewDidLoad()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupBindings() {
    viewModel.didUpdateButtons = { [weak customView] model in
      customView?.buttonsView.configure(model: model)
    }
    
    viewModel.didUpdateChartData = { [weak customView] model in
      customView?.chartView.configure(model: model)
      customView?.errorView.isHidden = true
      customView?.chartView.isHidden = false
    }
    
    viewModel.didUpdateHeader = { [weak customView] model in
      customView?.headerView.configure(configuration: model)
    }
    
    viewModel.didFailedUpdateChartData = { [weak customView] model in
      customView?.errorView.configure(model: model)
      customView?.errorView.isHidden = false
      customView?.chartView.isHidden = true
    }
  }
  
  private func setupViewEvents() {
    customView.chartView.didSelectValue = { [weak viewModel] index in
      viewModel?.didSelectChartPoint(at: index)
    }
    
    customView.chartView.didDeselectValue = { [weak viewModel] in
      viewModel?.didDeselectChartPoint()
    }
  }
}
