import UIKit
import TKUIKit

public final class AccountEventCellIconView: UIView, TKConfigurableView {
  private let imageView = TKUIListItemImageIconView()
    
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Configuration: Hashable {
    public let imageModel: TKUIListItemImageIconView.Configuration
    public init(imageModel: TKUIListItemImageIconView.Configuration) {
      self.imageModel = imageModel
    }
  }
  
  public func configure(configuration: Configuration) {
    imageView.configure(configuration: configuration.imageModel)
  }

  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    return imageView.sizeThatFits(size)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    imageView.frame = bounds
  }
}

private extension AccountEventCellIconView {
  func setup() {
    addSubview(imageView)
  }
}
