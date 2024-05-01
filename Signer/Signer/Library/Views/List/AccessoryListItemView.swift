import UIKit
import TKUIKit

final class AccessoryListItemView<ContentView: ConfigurableView>: UIView, ConfigurableView, GenericCollectionViewCellContentView {
  
  private let contentView = ContentView()
  private let accessoryView = ListItemAccessoryView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let accessorySize = accessoryView.sizeThatFits(.zero)
    accessoryView.frame = CGRect(
      origin: CGPoint(
        x: bounds.width - accessorySize.width,
        y: bounds.height/2 - accessorySize.height/2),
      size: accessorySize)
    
    let contentSize = contentView.sizeThatFits(.zero)
    contentView.frame = CGRect(
      origin: CGPoint(
        x: 0,
        y: bounds.height/2 - contentSize.height/2),
      size: CGSize(
        width: bounds.width - accessorySize.width,
        height: contentSize.height)
    )
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let accessorySize = accessoryView.sizeThatFits(size)
    let contentSize = contentView.sizeThatFits(size)
    let height = max(contentSize.height, accessorySize.height)
    return CGSize(width: size.width, height: height)
  }
  
  // MARK: - ConfigurableView
  
  class Model {
    let contentViewModel: ContentView.Model
    let accessoryModel: ListItemAccessoryView.Model
    
    init(contentViewModel: ContentView.Model, accessoryModel: ListItemAccessoryView.Model) {
      self.contentViewModel = contentViewModel
      self.accessoryModel = accessoryModel
    }
  }
  
  func configure(model: Model) {
    contentView.configure(model: model.contentViewModel)
    accessoryView.configure(model: model.accessoryModel)
    setNeedsLayout()
  }
}

private extension AccessoryListItemView {
  func setup() {
    addSubview(contentView)
    addSubview(accessoryView)
  }
}
