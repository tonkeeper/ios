import UIKit
import TKUIKit

final class PaymentMethodItemCell: TKCollectionViewContainerCell<PaymentMethodItemCellContentView> {
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .Background.content
    accessoryType = .none
    isSelectable = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Configuration: Hashable {
    public let id: String
    public let contentConfiguration: PaymentMethodItemCellContentView.Configuration
    
    public init(id: String,
                contentConfiguration: PaymentMethodItemCellContentView.Configuration) {
      self.id = id
      self.contentConfiguration = contentConfiguration
    }
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
      hasher.combine(contentConfiguration)
    }
    
    public static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
      lhs.id == rhs.id && lhs.contentConfiguration == rhs.contentConfiguration
    }
  }
  
  public func configure(configuration: Configuration) {
    cellContentView.configure(model: configuration.contentConfiguration)
    setNeedsLayout()
  }
  
  override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)
    UIView.animate(withDuration: 0.15) {
      self.configureRadioButton(isSelected: state.isSelected)
    }
  }
  
  private func configureRadioButton(isSelected: Bool) {
    let image = radioButtonIconImage(isSelected: isSelected)
    let tintColor = radioButtonIconTintColor(isSelected: isSelected)
    let iconModel = TKListItemIconImageView.Model(image: .image(image), tintColor: tintColor, backgroundColor: .clear, size: image.size)
    cellContentView.radioButtonView.configure(model: iconModel)
  }
  
  private func radioButtonIconImage(isSelected: Bool) -> UIImage {
    return isSelected ? .radioButtonIconEnabled : .radioButtonIconDisabled
  }
  
  private func radioButtonIconTintColor(isSelected: Bool) -> UIColor {
    return isSelected ? .Button.primaryBackground : .Button.tertiaryBackground
  }
}

final class PaymentMethodItemCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
  var padding: UIEdgeInsets { .init(top: 0, left: 16, bottom: 0, right: 16) }
  
  let radioButtonView = TKListItemIconImageView()
  let contentView = PaymentMethodContentView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let radioButtonSize = CGSize.iconViewSize
    let radioButtonCenterX = radioButtonSize.width / 2
    let radioButtonCenterY = bounds.height / 2
    radioButtonView.frame.size = radioButtonSize
    radioButtonView.center = CGPoint(x: radioButtonCenterX, y: radioButtonCenterY)
    
    let contentViewWidth = bounds.width - radioButtonSize.width
    let contentViewHeight = bounds.height
    contentView.frame = CGRect(x: radioButtonSize.width, y: 0, width: contentViewWidth, height: contentViewHeight)
  }
  
  struct Configuration: Hashable {
    let contentModel: PaymentMethodContentView.Model
  }
  
  func configure(model: Configuration) {
    let image = UIImage.TKUIKit.Icons.Size28.radioButtonDisabled
    let imageSize = image.size
    let iconModel = TKListItemIconImageView.Model(image: .image(image), tintColor: .red, backgroundColor: .clear, size: imageSize)
    radioButtonView.configure(model: iconModel)
    contentView.configure(model: model.contentModel)
  }
  
  func prepareForReuse() {
    radioButtonView.prepareForReuse()
    contentView.prepareForReuse()
  }
}

private extension PaymentMethodItemCellContentView {
  func setup() {
    addSubview(radioButtonView)
    addSubview(contentView)
  }
}

private extension CGSize {
  static let iconViewSize = CGSize(width: 28, height: 28)
}
private extension UIImage {
  static let radioButtonIconEnabled = UIImage.TKUIKit.Icons.Size28.radioButtonEnabled
  static let radioButtonIconDisabled = UIImage.TKUIKit.Icons.Size28.radioButtonDisabled
}
