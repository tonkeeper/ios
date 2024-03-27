import UIKit
import TKUIKit
import SnapKit

final class WalletColorEmojiBadgeView: UIView {
  
  var emoji = "" {
    didSet {
      emojiLabel.text = emoji
      animateEmojiLabel()
    }
  }
  
  var color: UIColor? {
    didSet {
      colorView.backgroundColor = color
    }
  }
  
  var padding: UIEdgeInsets = .zero {
    didSet {
      colorView.snp.updateConstraints { make in
        make.edges.equalTo(self).inset(padding)
      }
    }
  }
  
  private let colorView: UIView = {
    let view = UIView()
    view.layer.cornerRadius = 8
    return view
  }()
  
  private let emojiLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 32)
    label.textAlignment = .right
    label.isUserInteractionEnabled = false
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension WalletColorEmojiBadgeView {
  func setup() {
    addSubview(colorView)
    addSubview(emojiLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    colorView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(padding)
      make.width.height.equalTo(CGFloat.colorViewSide)
    }
    emojiLabel.snp.makeConstraints { make in
      make.center.equalTo(self)
    }
  }
  
  private func animateEmojiLabel() {
    animateEmojiLabelTransform(CGAffineTransform(scaleX: 1.1, y: 1.1)) { [weak self] in
      self?.animateEmojiLabelTransform(.identity)
    }
  }
  
  private func animateEmojiLabelTransform(_ transform: CGAffineTransform,
                                          completion: (() -> Void)? = nil) {
    UIView.animate(
      withDuration: 0.1,
      delay: 0,
      options: [.curveEaseIn],
      animations: {
        self.emojiLabel.transform = transform
      },
      completion: { _ in
        completion?()
      })
  }
}

private extension CGFloat {
  static let emojiLabelSide: CGFloat = 36
  static let colorViewSide: CGFloat = 48
}
