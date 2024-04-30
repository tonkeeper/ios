import UIKit

public final class TKUIKeyboardButtonPlainBackgroundView: UIView {
  
  var state: TKButtonState = .normal {
    didSet {
      setupState()
    }
  }
  
  let highlighView: UIView = {
    let view = UIView()
    view.isUserInteractionEnabled = false
    return view
  }()
  
  public override init(frame: CGRect) {
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    highlighView.layer.cornerRadius = bounds.height/2
  }
}

private extension TKUIKeyboardButtonPlainBackgroundView {
  func setup() {
    addSubview(highlighView)
    
    setupConstraints()
    setupState()
  }
  
  func setupConstraints() {
    highlighView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      highlighView.widthAnchor.constraint(equalTo: heightAnchor),
      highlighView.heightAnchor.constraint(equalTo: heightAnchor),
      highlighView.centerXAnchor.constraint(equalTo: centerXAnchor),
      highlighView.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }
  
  func setupState() {
    let backgroundColor: UIColor
    let transform: CGAffineTransform
    switch state {
    case .normal, .disabled, .selected:
      backgroundColor = .clear
      transform = CGAffineTransform(
        scaleX: .notHighlightedScale,
        y: .notHighlightedScale
      )
    case .highlighted:
      backgroundColor = .Button.secondaryBackgroundHighlighted
      transform = .identity
    }
    UIView.animate(withDuration: 0.2) { [highlighView] in
      highlighView.backgroundColor = backgroundColor
      highlighView.transform = transform
    }
    
  }
}

private extension CGFloat {
  static let notHighlightedScale: CGFloat = 0.8
}
