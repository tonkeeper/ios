import UIKit
import TKUIKit

final class TKInputRecoveryPhraseSuggestsButton: UIControl, ConfigurableView {
  
  public override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      setupState()
    }
  }
  
  let textLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height/2
  }
  
  struct Model {
    let text: String
    let action: () -> Void
  }
  
  func configure(model: Model) {
    textLabel.text = model.text
    addAction(UIAction(handler: { _ in
      model.action()
    }), for: .touchUpInside)
  }
}

private extension TKInputRecoveryPhraseSuggestsButton {
  func setup() {
    textLabel.font = TKTextStyle.label2.font
    textLabel.textColor = .Button.secondaryForeground
    textLabel.textAlignment = .center
    
    addSubview(textLabel)
    
    setupConstraints()
    
    setupState()
  }
  
  func setupConstraints() {
    textLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      textLabel.topAnchor.constraint(equalTo: topAnchor),
      textLabel.leftAnchor.constraint(equalTo: leftAnchor),
      textLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
      textLabel.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func setupState() {
    switch state {
    case .normal:
      backgroundColor = .clear
    case .highlighted:
      backgroundColor = .Background.contentAttention
    default:
      break
    }
  }
}
