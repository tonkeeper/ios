import UIKit
import TKUIKit

extension HistoryCellActionView {
  final class EncyptedCommentView: UIControl, ConfigurableView, ReusableView {
    
    let spoilerView = TKSpoilerView()
    
    let textBackground: UIView = {
      let view = UIView()
      view.backgroundColor = .Bubble.background
      view.layer.cornerRadius = .cornerRadius
      return view
    }()
    
    let textLabel: UILabel = {
      let label = UILabel()
      label.backgroundColor = .Bubble.background
      label.numberOfLines = 0
      return label
    }()
    
    private var action: (() -> Void)?
    
    struct Model {
      enum State {
        case encrypted(text: NSAttributedString?)
        case decrypted(text: NSAttributedString?)
      }
      
      let state: State
      let action: (() -> Void)?
      
      init(encryptedText: String, action: @escaping () -> Void) {
        let count = encryptedText.count / 2 - 64
        let string = String(repeating: "0", count: count)
        self.state = .encrypted(text: string.withTextStyle(.body2, color: .Bubble.foreground))
        self.action = action
      }
      
      init(decryptedText: String?) {
        self.state = .decrypted(text: decryptedText?.withTextStyle(.body2, color: .Bubble.foreground))
        self.action = nil
      }
    }
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
      super.layoutSubviews()
      
      let textAvailableWidth = bounds.width - .textHorizontalSpacing * 2
      let textSize = textLabel.tkSizeThatFits(textAvailableWidth)
      
      textBackground.frame = .init(x: 0,
                                   y: .topSpace,
                                   width: textSize.width + .textHorizontalSpacing * 2,
                                   height: textSize.height + .textTopSpacing + .textBottomSpacing)
      textLabel.frame = .init(x: .textHorizontalSpacing,
                              y: .textTopSpacing,
                              width: textBackground.bounds.width - .textHorizontalSpacing * 2,
                              height: textBackground.bounds.height - .textBottomSpacing - .textTopSpacing)
      
      spoilerView.frame = textLabel.frame
      
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
      guard let text = textLabel.text, !text.isEmpty else { return .zero }
      let textWidth = size.width - .textHorizontalSpacing * 2
      let textSize = textLabel.tkSizeThatFits(textWidth)
      return .init(width: textSize.width + .textHorizontalSpacing * 2,
                   height: textSize.height + .textTopSpacing + .textBottomSpacing + .topSpace)
    }
    
    func configure(model: Model) {
      self.action = model.action
      switch model.state {
      case .encrypted(let text):
        textLabel.alpha = 0
        textLabel.attributedText = text
        spoilerView.isOn = true
      case .decrypted(let text):
        textLabel.alpha = 1
        textLabel.attributedText = text
        spoilerView.isOn = false
      }
      setNeedsLayout()
    }
    
    func prepareForReuse() {
      textLabel.attributedText = nil
    }
  }
}

private extension HistoryCellActionView.EncyptedCommentView {
  func setup() {
    textBackground.isUserInteractionEnabled = false
    
    addSubview(textBackground)
    textBackground.addSubview(textLabel)
    textBackground.addSubview(spoilerView)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.action?()
    }), for: .touchUpInside)
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 12
  static let textTopSpacing: CGFloat = 7.5
  static let textBottomSpacing: CGFloat = 8.5
  static let textHorizontalSpacing: CGFloat = 12
  static let topSpace: CGFloat = 8
}
