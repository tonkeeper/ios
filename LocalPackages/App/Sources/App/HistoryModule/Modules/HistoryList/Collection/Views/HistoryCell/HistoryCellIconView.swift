import UIKit
import TKUIKit

final class HistoryCellIconView: UIView, TKConfigurableView {
  private let imageView = TKUIListItemImageIconView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Configuration: Hashable {
    let imageModel: TKUIListItemImageIconView.Configuration
    let isInProgress: Bool
  }
  
  func configure(configuration: Configuration) {
    imageView.configure(configuration: configuration.imageModel)
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return imageView.sizeThatFits(size)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    imageView.frame = bounds
  }
}

private extension HistoryCellIconView {
  func setup() {
    addSubview(imageView)
  }
}
