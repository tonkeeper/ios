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
    
    viewModel.viewDidLoad()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupBindings() {
    viewModel.didUpdateButtons = { [weak customView] model in
      customView?.buttonsView.configure(model: model)
    }
    
    viewModel.didUpdateChartData = { [weak customView] model in
      customView?.chartView.setData(model)
    }
  }
  
  private func setupViewEvents() {
  }
}
