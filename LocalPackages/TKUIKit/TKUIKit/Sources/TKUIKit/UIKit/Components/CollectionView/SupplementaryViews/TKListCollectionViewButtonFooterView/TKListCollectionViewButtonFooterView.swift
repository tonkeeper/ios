import UIKit

public final class TKListCollectionViewButtonFooterView: UICollectionReusableView {
  
  public static var elementKind = "TKListCollectionViewButtonFooterView"
  
  public struct Configuration: Hashable {
    public let identifier: String
    public let content: TKButton.Configuration.Content
    public let action: (() -> Void)?
    
    public init(identifier: String,
                content: TKButton.Configuration.Content,
                action: (() -> Void)?) {
      self.identifier = identifier
      self.content = content
      self.action = action
    }
    
    public static func == (lhs: Configuration, rhs: Configuration) -> Bool {
      lhs.identifier == rhs.identifier
    }
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
  }
  
  public var configuration = Configuration(identifier: "", content: .default, action: nil) {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let button = TKButton(configuration: .actionButtonConfiguration(category: .secondary, size: .small))
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(button)
    setupConstraints()
  }
  
  private func setupConstraints() {
    button.setContentHuggingPriority(.required, for: .horizontal)
    
    button.snp.makeConstraints { make in
      make.top.equalTo(self).inset(16)
      make.left.right.greaterThanOrEqualTo(self).inset(16).priority(.high)
      make.bottom.equalTo(self)
      make.centerX.equalTo(self)
    }
  }
  
  private func didUpdateConfiguration() {
    button.configuration.content = configuration.content
    button.configuration.action = configuration.action
  }
}
