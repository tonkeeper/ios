import UIKit
import TKUIKit

class HistoryCell: TKCollectionViewNewCell, ConfigurableView {
  let historyCellContentView = HistoryCellContentView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func contentSize(targetWidth: CGFloat) -> CGSize {
    return historyCellContentView.sizeThatFits(CGSize(width: targetWidth, height: 0))
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    historyCellContentView.frame = contentContainerView.bounds
  }
  
  struct Model {
    let id: String
    let historyContentConfiguration: HistoryCellContentView.Model
  }
  
  func configure(model: Model) {
    historyCellContentView.configure(model: model.historyContentConfiguration)
    setNeedsLayout()
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    historyCellContentView.prepareForReuse()
  }
}

private extension HistoryCell {
  func setup() {
    isSeparatorVisible = false
    addSubview(historyCellContentView)
  }
}
