import UIKit
import SnapKit

public final class TKKeyboardButton: UIControl, ConfigurableView {
  
  public override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      didUpdateIsHightlighted(isHighlighted)
    }
  }
  
  private let contentContainer = UIView()
  private let imageView = UIImageView()
  private let titleLabel = UILabel()
  private let highlightView = UIView()
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    highlightView.layer.cornerRadius = bounds.height/2
  }
  
  public enum Model {
    case none
    case text(String)
    case image(UIImage)
  }
  
  public func configure(model: Model) {
    switch model {
    case .none:
      imageView.image = nil
      titleLabel.text = nil
      contentContainer.isHidden = true
    case .text(let text):
      titleLabel.attributedText = text.withTextStyle(
        .num1,
        color: .Text.primary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
      imageView.image = nil
      contentContainer.isHidden = false
      titleLabel.isHidden = false
      imageView.isHidden = true
    case .image(let image):
      imageView.image = image
      titleLabel.text = nil
      imageView.isHidden = false
      contentContainer.isHidden = false
      titleLabel.isHidden = true
    }
  }
}

private extension TKKeyboardButton {
  func setup() {
    backgroundColor = .Background.page
    
    imageView.isHidden = true
    imageView.contentMode = .center
    imageView.tintColor = .Text.primary
    
    titleLabel.isHidden = true
    
    highlightView.backgroundColor = .clear
    highlightView.isUserInteractionEnabled = false
    
    addSubview(highlightView)
    addSubview(contentContainer)
    contentContainer.addSubview(imageView)
    contentContainer.addSubview(titleLabel)
    
    contentContainer.snp.makeConstraints { make in
      make.center.equalTo(self)
    }
    
    imageView.snp.makeConstraints { make in
      make.center.equalTo(contentContainer)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.center.equalTo(contentContainer)
    }
    
    highlightView.snp.makeConstraints { make in
      make.width.height.equalTo(snp.height)
      make.center.equalTo(self)
    }
  }
  
  func didUpdateIsHightlighted(_ isHighlighted: Bool) {
    let backgroundColor: UIColor
    let transform: CGAffineTransform
    
    if isHighlighted {
      backgroundColor = .Button.secondaryBackgroundHighlighted
      transform = .identity
    } else {
      backgroundColor = .clear
      transform = CGAffineTransformMakeScale(0.8, 0.8)
    }
    UIView.animate(withDuration: 0.2) {
      self.highlightView.backgroundColor = backgroundColor
      self.highlightView.transform = transform
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 72
}
