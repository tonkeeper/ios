import UIKit
import SnapKit

public final class ModalTitleView: UIView, ConfigurableView {
  
  private let titleLabel: UILabel = .centeredLabel()
  private let descriptionLabel: UILabel = .centeredLabel()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.distribution = .fillProportionally
    return stackView
  }()
  
  public override var intrinsicContentSize: CGSize { sizeThatFits(bounds.size) }
  
  convenience init(model: Model) {
    self.init(frame: .zero)
    self.configure(model: model)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let titleWidth = titleLabel.sizeThatFits(size).width
    let descriptionWidth = descriptionLabel.sizeThatFits(size).width
    let width = max(titleWidth, descriptionWidth)
    
    let height: CGFloat
    if descriptionLabel.text != nil {
      height = 48
    } else {
      height = 28
    }
    
    return CGSize(width: width, height: height)
  }
  
  public struct Model {
    let title: String
    let description: String?
    
    public init(title: String, description: String? = nil) {
      self.title = title
      self.description = description
    }
  }
  
  public func configure(model: Model) {
    titleLabel.text = model.title
    if let subtitle = model.description {
      descriptionLabel.isHidden = false
      descriptionLabel.text = subtitle
    } else {
      descriptionLabel.isHidden = true
    }
  }
}

private extension ModalTitleView {
  func setup() {
    titleLabel.font = TKTextStyle.h3.font
    descriptionLabel.font = TKTextStyle.body2.font
    
    titleLabel.textColor = .Text.primary
    descriptionLabel.textColor = .Text.secondary
    
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(descriptionLabel)
    addSubview(stackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}

private extension UILabel {
  static func centeredLabel() -> UILabel {
    let label = UILabel()
    label.textAlignment = .center
    return label
  }
}
