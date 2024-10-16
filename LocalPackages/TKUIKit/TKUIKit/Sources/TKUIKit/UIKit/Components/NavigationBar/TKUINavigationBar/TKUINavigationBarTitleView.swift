import UIKit

public final class TKUINavigationBarTitleView: UIView, ConfigurableView {
  
  public struct Model {
    public let title: NSAttributedString?
    public let caption: TKPlainButton.Model?
    
    public init(title: NSAttributedString?, caption: TKPlainButton.Model? = nil) {
      self.title = title
      self.caption = caption
    }
    
    public init(title: String?, caption: TKPlainButton.Model? = nil) {
      self.title = title?.withTextStyle(.h3, color: .Text.primary, alignment: .center, lineBreakMode: .byTruncatingTail)
      self.caption = caption
    }
  }
  
  public func configure(model: Model) {
    topLabel.attributedText = model.title
    if let caption = model.caption {
      captionButton.configure(model: caption)
      captionButton.isHidden = false
    } else {
      captionButton.isHidden = true
    }
  }
  
  private let topLabel = UILabel()
  private let captionButton = TKPlainButton()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .center
    return stackView
  }()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    topLabel.minimumScaleFactor = 0.3
    topLabel.adjustsFontSizeToFitWidth = true
    
    addSubview(stackView)
    stackView.addArrangedSubview(topLabel)
    stackView.addArrangedSubview(captionButton)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
