import UIKit
import TKUIKit

extension HistoryCellActionView {
  
  final class NFTView: UIControl, ReusableView {
    private let contentView = UIView()
    private let highlightView = TKHighlightView()
    private let imageView = TKImageView()
    private let nameLabel = UILabel()
    private let collectionNameLabel = UILabel()
    private let collectionVerificationImageView: UIImageView = {
      let imageView = UIImageView()
      imageView.contentMode = .center
      imageView.image = .TKUIKit.Icons.Size16.verification
      imageView.tintColor = .Icon.secondary
      imageView.isHidden = true
      return imageView
    }()
    private let blurView = TKSecureBlurView()
    
    override var isHighlighted: Bool {
      didSet {
        highlightView.isHighlighted = isHighlighted
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
      contentView.frame = bounds
      contentView.frame.origin.y += 8
      contentView.frame.size.height -= 8
      
      highlightView.frame = contentView.bounds
      
      imageView.frame = CGRect(
        origin: .zero,
        size: CGSize(width: .imageSize, height: .imageSize)
      )
      blurView.frame = imageView.frame
      
      let verificationViewSideEffect: CGFloat = collectionVerificationImageView.isHidden ? 0 : .verificationImageSide
      let textSize = CGSize(
        width: bounds.width - .imageSize - UIEdgeInsets.textContentPadding.horizontal - verificationViewSideEffect,
        height: 0
      )

      let nameSize = nameLabel.tkSizeThatFits(textSize.width)
      nameLabel.frame = CGRect(
        origin: CGPoint(
          x: imageView.frame.maxX + UIEdgeInsets.textContentPadding.left,
          y: contentView.bounds.size.height/2 - nameSize.height
        ),
        size: nameSize
      )
      
      let collectionNameSize = collectionNameLabel.tkSizeThatFits(textSize.width)
      collectionNameLabel.frame = CGRect(
        origin: CGPoint(
          x: imageView.frame.maxX + UIEdgeInsets.textContentPadding.left,
          y: contentView.bounds.size.height/2
        ),
        size: collectionNameSize
      )
      collectionVerificationImageView.frame = CGRect(
        x: collectionNameLabel.frame.maxX + 4,
        y: collectionNameLabel.frame.midY - .verificationImageSide/2,
        width: .verificationImageSide,
        height: .verificationImageSide
      )
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
      var textWidth = size.width
      textWidth -= .imageSize
      textWidth -= UIEdgeInsets.textContentPadding.horizontal
      if !collectionVerificationImageView.isHidden {
        textWidth -= .verificationImageSide
      }

      let nameSize = nameLabel.tkSizeThatFits(CGSize(width: textWidth, height: 0))
      let collectionNameSize = collectionNameLabel.tkSizeThatFits(CGSize(width: textWidth, height: 0))

      var width = ([nameSize.width, collectionNameSize.width].max() ?? 0)
      width += .imageSize
      width += UIEdgeInsets.textContentPadding.horizontal
      if !collectionVerificationImageView.isHidden {
        width += .verificationImageSide
      }
      return CGSize(width: width, height: .height + 8)
    }
    
    struct Configuration {
      let imageModel: TKImageView.Model
      let name: NSAttributedString?
      let collectionName: NSAttributedString?
      let isVerified: Bool
      let isBlurVisible: Bool
      let action: () -> Void
      
      init(imageModel: TKImageView.Model,
           name: String?,
           collectionName: String?,
           isSuspecious: Bool,
           isVerified: Bool,
           isBlurVisible: Bool,
           action: @escaping () -> Void) {
        self.imageModel = imageModel
        self.name = name?.withTextStyle(
          .body2,
          color: .Bubble.foreground,
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        )

        let color: UIColor = isSuspecious ? .Accent.orange : .Bubble.foreground.withAlphaComponent(0.64)
        self.collectionName = collectionName?
          .withTextStyle(
            .body2,
            color: color,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          )
        self.isVerified = isVerified
        self.isBlurVisible = isBlurVisible
        self.action = action
      }
    }
    
    func configure(configuration: Configuration) {
      blurView.isHidden = !configuration.isBlurVisible
      nameLabel.attributedText = configuration.name
      collectionNameLabel.attributedText = configuration.collectionName
      collectionVerificationImageView.isHidden = !configuration.isVerified
      imageView.configure(model: configuration.imageModel)
      enumerateEventHandlers { action, targetAction, event, stop in
        if let action = action {
          self.removeAction(action, for: event)
        }
      }
      addAction(UIAction(handler: { _ in
        configuration.action()
      }), for: .touchUpInside)
    }
    
    func prepareForReuse() {
      imageView.prepareForReuse()
      nameLabel.text = nil
      collectionNameLabel.text = nil
    }
  }
}

private extension HistoryCellActionView.NFTView {

  func setup() {
    isExclusiveTouch = true
    
    blurView.isHidden = true
    
    contentView.backgroundColor = .Bubble.background
    contentView.isUserInteractionEnabled = false
    
    contentView.layer.cornerRadius = .cornerRadius
    contentView.layer.masksToBounds = true
    
    highlightView.alpha = 1
    
    addSubview(contentView)
    contentView.addSubview(highlightView)
    contentView.addSubview(imageView)
    contentView.addSubview(blurView)
    contentView.addSubview(nameLabel)
    contentView.addSubview(collectionNameLabel)
    contentView.addSubview(collectionVerificationImageView)
  }
}

private extension CGFloat {
  static let topInset: CGFloat = 8
  static let cornerRadius: CGFloat = 12
  static let imageSize: CGFloat = 64
  static let verificationImageSide: CGFloat = 16
  static let width: CGFloat = 176
  static let height: CGFloat = 64
  static let labelsSideSpace: CGFloat = 12
}

private extension UIEdgeInsets {
  static let textContentPadding = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
  var horizontal: CGFloat { left + right }
}

