import UIKit

public final class TKButtonCollectionViewCell: UICollectionViewCell {
  
  public struct Configuration {
    public let buttonConfiguration: TKButton.Configuration
    
    public init(buttonConfiguration: TKButton.Configuration) {
      self.buttonConfiguration = buttonConfiguration
    }
  }
  
  public var configuration = Configuration(buttonConfiguration: .actionButtonConfiguration(category: .secondary, size: .large)) {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  private let button = TKButton()

  private let container = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(container)
    container.addSubview(button)
    
    container.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    button.snp.makeConstraints { make in
      make.top.bottom.equalTo(container)
      make.centerX.equalTo(container)
      make.left.equalTo(container)
      make.right.equalTo(container)
    }
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    button.configuration = configuration.buttonConfiguration
  }
}
