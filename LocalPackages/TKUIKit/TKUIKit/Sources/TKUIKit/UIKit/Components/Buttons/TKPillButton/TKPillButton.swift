import UIKit

public final class TKPillButton: UIView {
  
  public struct Configuration {
    public struct Button {
      public let icon: UIImage
      public let action: () -> Void
      
      public init(icon: UIImage, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
      }
    }
    
    public let leftButton: Button
    public let rightButton: Button
    
    public init(leftButton: Button, rightButton: Button) {
      self.leftButton = leftButton
      self.rightButton = rightButton
    }
    
    public static var `default`: Configuration {
      Configuration(
        leftButton: Button(icon: .TKUIKit.Icons.Size16.ellipses, action: {}),
        rightButton: Button(icon: .TKUIKit.Icons.Size16.close, action: {})
      )
    }
  }
  
  public var configuration: Configuration = .default {
    didSet {
      didUpdateConfiguration()
    }
  }
  
  private let leftButton = TKButton()
  private let rightButton = TKButton()
  private let divider = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height/2
  }
  
  private func setup() {
    backgroundColor = .Button.secondaryBackground
    layer.masksToBounds = true
    
    divider.backgroundColor = .Background.contentTint
    
    addSubview(leftButton)
    addSubview(divider)
    addSubview(rightButton)
    
    setupConstraints()
    
    didUpdateConfiguration()
  }
  
  private func setupConstraints() {
    leftButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    rightButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    divider.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    leftButton.snp.makeConstraints { make in
      make.left.top.bottom.equalTo(self)
    }
    divider.snp.makeConstraints { make in
      make.top.bottom.equalTo(self).inset(8)
      make.width.equalTo(1)
      make.left.equalTo(leftButton.snp.right)
    }
    rightButton.snp.makeConstraints { make in
      make.top.right.bottom.equalTo(self)
      make.left.equalTo(divider.snp.right)
    }
  }
  
  private func didUpdateConfiguration() {
    func buttonConfiguration(configuration: Configuration.Button) -> TKButton.Configuration {
      TKButton.Configuration(
        content: TKButton.Configuration.Content(icon: configuration.icon),
        contentPadding: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12),
        iconTintColor: .Icon.primary,
        contentAlpha: [
          .normal: 1,
          .highlighted: 0.44
        ],
        action: configuration.action
      )
    }
    
    leftButton.configuration = buttonConfiguration(configuration: configuration.leftButton)
    rightButton.configuration = buttonConfiguration(configuration: configuration.rightButton)
  }
}
