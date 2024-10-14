import UIKit

typealias BatteryRefillFooterCellRegistration = UICollectionView.CellRegistration<BatteryRefillFooterCell, BatteryRefillFooterView.Configuration>
extension BatteryRefillFooterCellRegistration {
  static func registration(collectionView: UICollectionView) -> BatteryRefillFooterCellRegistration {
    BatteryRefillFooterCellRegistration { cell, indexPath, configuration in
      cell.view.configuration = configuration
    }
  }
}

final class BatteryRefillFooterCell: UICollectionViewCell {
  
  let view = BatteryRefillFooterView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    contentView.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(contentView)
    }
  }
}
