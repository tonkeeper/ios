import UIKit
import TKUIKit

final class BrowserAppCollectionViewCell: UICollectionViewCell, ReusableView, TKConfigurableView {
  
  var didLongPress: (() -> Void)?
  
  let iconImageView = TKImageView()
  let titleLabel = UILabel()
  
  override var isHighlighted: Bool {
    didSet {
      alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    iconImageView.prepareForReuse()
  }
  
  struct Configuration: Hashable {
    let id: UUID
    let title: NSAttributedString
    let iconModel: TKImageView.Model
    let selectionClosure: (() -> Void)?
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
    
    static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
      return lhs.id == rhs.id
    }
    
    init(id: UUID,
         title: String,
         iconModel: TKImageView.Model,
         selectionClosure: (() -> Void)?) {
      self.id = id
      self.title = title.withTextStyle(
        .body3,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
      self.iconModel = iconModel
      self.selectionClosure = selectionClosure
    }
  }
  
  func configure(configuration: Configuration) {
    titleLabel.attributedText = configuration.title
    iconImageView.configure(model: configuration.iconModel)
    setNeedsLayout()
  }
}

private extension BrowserAppCollectionViewCell {
  func setup() {
    addSubview(titleLabel)
    addSubview(iconImageView)
    
    iconImageView.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.centerX.equalTo(self)
      make.size.equalTo(64)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.top.equalTo(iconImageView.snp.bottom)
      make.left.right.equalTo(self)
      make.bottom.equalTo(self).offset(-8)
    }
    
    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureHandler(recognizer:)))
    longPressGesture.minimumPressDuration = 0.5
    addGestureRecognizer(longPressGesture)
  }
  
  @objc
  func longPressGestureHandler(recognizer: UILongPressGestureRecognizer) {
    switch recognizer.state {
    case .began:
      didLongPress?()
    default:
      break
    }
  }
}
