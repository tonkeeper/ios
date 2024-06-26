import UIKit
import TKUIKit
import SnapKit

final class WalletColorIconBadgeView: UIView {

  enum Model {
    case emoji(String)
    case image(UIImage?)
  }
  
  var icon: Model? {
    didSet {
      switch icon {
      case .emoji(let emoji):
        iconImageView.isHidden = true
        iconImageView.image = nil
        emojiLabel.isHidden = false
        emojiLabel.text = emoji
        animateEmojiLabel()
      case .image(let image):
        iconImageView.isHidden = false
        iconImageView.image = image
        emojiLabel.isHidden = true
        emojiLabel.text = nil
        animateImageView()
      case nil:
        iconImageView.isHidden = true
        iconImageView.image = nil
        emojiLabel.isHidden = true
        emojiLabel.text = nil
      }
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
    label.isHidden = true
    return label
  }()
  
  private let iconImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .Icon.primary
    imageView.isHidden = true
    return imageView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension WalletColorIconBadgeView {
  func setup() {
    addSubview(colorView)
    addSubview(emojiLabel)
    addSubview(iconImageView)
    
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
    
    iconImageView.snp.makeConstraints { make in
      make.center.equalTo(self)
      make.width.height.equalTo(32)
    }
  }
  
  private func animateImageView() {
    animateViewTransform(view: iconImageView, transform: CGAffineTransform(scaleX: 1.1, y: 1.1)) { [weak self, iconImageView] in
      self?.animateViewTransform(view: iconImageView, transform: .identity)
    }
  }
  
  private func animateEmojiLabel() {
    animateViewTransform(view: emojiLabel, transform: CGAffineTransform(scaleX: 1.1, y: 1.1)) { [weak self, emojiLabel] in
      self?.animateViewTransform(view: emojiLabel, transform: .identity)
    }
  }
  
  private func animateViewTransform(view: UIView,
                                    transform: CGAffineTransform,
                                    completion: (() -> Void)? = nil) {
    UIView.animate(
      withDuration: 0.1,
      delay: 0,
      options: [.curveEaseIn],
      animations: {
        view.transform = transform
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
