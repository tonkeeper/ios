import UIKit

public final class TKListCollectionViewButtonHeaderView: UICollectionReusableView {
  
  public static var elementKind = "TKListCollectionViewButtonHeaderView"
  
  public struct Configuration: Hashable {
    public let identifier: String
    public let title: NSAttributedString
    public let buttonConfiguration: TKButton.Configuration?
    
    public init(identifier: String,
                title: String,
                buttonConfiguration: TKButton.Configuration? = nil) {
      self.identifier = identifier
      self.title = title.withTextStyle(.label1, color: .Text.primary)
      self.buttonConfiguration = buttonConfiguration
    }
    
    public static func == (lhs: Configuration, rhs: Configuration) -> Bool {
      lhs.identifier == rhs.identifier
    }
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
  }
  
  public var configuration = Configuration(identifier: "", title: "") {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let titleLabel = UILabel()
  let button = TKButton()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    titleLabel.numberOfLines = 1
    
    addSubview(titleLabel)
    addSubview(button)
    
    setupConstraints()
    didUpdateConfiguration()
  }
  
  private func setupConstraints() {
    titleLabel.snp.makeConstraints { make in
      make.left.equalTo(self).inset(2)
      make.top.bottom.equalTo(self).inset(12)
    }
    
    button.snp.makeConstraints { make in
      make.centerY.equalTo(self)
      make.right.equalTo(self)
    }
  }
  
  private func didUpdateConfiguration() {
    titleLabel.attributedText = configuration.title
    if let buttonConfiguration = configuration.buttonConfiguration {
      button.isHidden = false
      button.configuration = buttonConfiguration
    } else {
      button.isHidden = true
    }
  }
}
