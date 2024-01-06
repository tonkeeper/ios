import UIKit
import TKUIKitLegacy

public final class ButtonTitleContentView: UIView, TKButtonTextContent {

  let label = UILabel()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: TKButtonContent
  
  public func width(withHeight height: CGFloat) -> CGFloat {
    label.sizeThatFits(.init(width: 0, height: height)).width
  }
  
  public func setForegroundColor(_ color: UIColor) {
    label.textColor = color
  }
  
  public func setTextStyle(_ textStyle: TextStyle) {
    label.font = textStyle.font
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    let title: String
    
    public init(title: String) {
      self.title = title
    }
  }
  
  public func configure(model: Model) {
    label.text = model.title
  }
}

private extension ButtonTitleContentView {
  func setup() {
    label.textAlignment = .center
    addSubview(label)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    label.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: topAnchor),
      label.leftAnchor.constraint(equalTo: leftAnchor),
      label.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      label.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
