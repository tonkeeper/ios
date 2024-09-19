import UIKit
import TKUIKit

final class SettingsPurchasesItemControl: UIControl, ConfigurableView {
  
  struct Model {
    enum Action {
      case plus
      case minus
    }
   
    let action: Action
    let tapClosure: () -> Void
  }
  
  func configure(model: Model) {
    switch model.action {
    case .plus:
      imageView.image = .TKUIKit.Icons.Size16.plus
    case .minus:
      imageView.image = .TKUIKit.Icons.Size16.minus
    }
    self.tapClosure = model.tapClosure
  }
  
  override var isHighlighted: Bool {
    didSet {
      alpha = isHighlighted ? 0.64 : 1
    }
  }
  
  private var tapClosure: (() -> Void)?
  
  private let circleView: UIView = {
    let view = UIView()
    view.isUserInteractionEnabled = false
    view.backgroundColor = .Background.contentTint
    view.layer.cornerRadius = .circleSide/2
    return view
  }()
  
  private let imageView: UIImageView = {
    let view = UIImageView()
    view.isUserInteractionEnabled = false
    view.tintColor = .Icon.primary
    view.contentMode = .center
    return view
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let circleFrame = CGRect(x: bounds.midX - .circleSide/2,
                             y: bounds.midY - .circleSide/2,
                             width: .circleSide,
                             height: .circleSide)
    circleView.frame = circleFrame
    imageView.frame = circleFrame
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: .width, height: size.height)
  }
  
  private func setup() {
    addSubview(circleView)
    addSubview(imageView)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.tapClosure?()
    }), for: .touchUpInside)
  }
}

private extension CGFloat {
  static let circleSide: CGFloat = 24
  static let width: CGFloat = 28
}
