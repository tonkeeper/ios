import UIKit
import TKUIKit
import TKChart
import SnapKit
import KeeperCore

final class ChartView: UIView {
  
  let headerView = ChartHeaderView()
  let buttonsView = ChartButtonsView()
  let chartView = TKLineChartView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(headerView)
    addSubview(chartView)
    addSubview(buttonsView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    headerView.snp.makeConstraints { make in
      make.left.top.right.equalTo(self)
    }
    
    chartView.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.top.equalTo(headerView.snp.bottom)
      make.height.equalTo(220)
    }
    
    buttonsView.snp.makeConstraints { make in
      make.top.equalTo(chartView.snp.bottom)
      make.left.bottom.right.equalTo(self)
    }
  }
}
