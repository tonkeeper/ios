import UIKit
import TKUIKit

extension HistoryCellActionView {
  
  final class NFTView: UIControl, TKConfigurableView, ReusableView {
    private let contentView = UIView()
    private let highlightView = TKHighlightView()
    private let imageView = UIImageView()
    private let nameLabel = UILabel()
    private let collectiomNameLabel = UILabel()
    
    private var imageDownloadTask: ImageDownloadTask?
    
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
      
      let textSize = CGSize(width: bounds.width - .imageSize - UIEdgeInsets.textContentPadding.left - UIEdgeInsets.textContentPadding.right, height: 0)
      
      let nameSize = nameLabel.tkSizeThatFits(textSize.width)
      nameLabel.frame = CGRect(
        origin: CGPoint(
          x: imageView.frame.maxX + UIEdgeInsets.textContentPadding.left,
          y: contentView.bounds.size.height/2 - nameSize.height
        ),
        size: nameSize
      )
      
      let collectionNameSize = collectiomNameLabel.tkSizeThatFits(textSize.width)
      collectiomNameLabel.frame = CGRect(
        origin: CGPoint(
          x: imageView.frame.maxX + UIEdgeInsets.textContentPadding.left,
          y: contentView.bounds.size.height/2
        ),
        size: collectionNameSize
      )
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
      let textWidth = size.width - .imageSize - UIEdgeInsets.textContentPadding.left - UIEdgeInsets.textContentPadding.right
      let nameSize = nameLabel.tkSizeThatFits(CGSize(width: textWidth, height: 0))
      let collectionNameSize = collectiomNameLabel.tkSizeThatFits(CGSize(width: textWidth, height: 0))
      let width = ([nameSize.width, collectionNameSize.width].max() ?? 0) + .imageSize + UIEdgeInsets.textContentPadding.left + UIEdgeInsets.textContentPadding.right
      return CGSize(width: width, height: .height + 8)
    }
    
    struct Configuration: Hashable {
      let imageDownloadTask: ImageDownloadTask?
      let imageUrl: URL?
      let name: NSAttributedString?
      let collectionName: NSAttributedString?
      let action: () -> Void
      
      init(imageDownloadTask: ImageDownloadTask?,
           imageUrl: URL?,
           name: String?,
           collectionName: String?,
           action: @escaping () -> Void) {
        self.imageDownloadTask = imageDownloadTask
        self.imageUrl = imageUrl
        self.name = name?.withTextStyle(
          .body2,
          color: .Bubble.foreground,
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        )
        self.collectionName = collectionName?.withTextStyle(
          .body2,
          color: .Bubble.foreground.withAlphaComponent(0.64),
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        )
        self.action = action
      }
      
      func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(collectionName)
        hasher.combine(imageUrl)
      }
      
      static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
        lhs.name == rhs.name && lhs.collectionName == rhs.collectionName && lhs.imageUrl == rhs.imageUrl
      }
    }
    
    func configure(configuration: Configuration) {
      nameLabel.attributedText = configuration.name
      collectiomNameLabel.attributedText = configuration.collectionName
      imageDownloadTask = configuration.imageDownloadTask
      imageDownloadTask?.start(
        imageView: imageView,
        size: CGSize(width: .imageSize, height: .imageSize),
        cornerRadius: nil
      )
      enumerateEventHandlers { action, targetAction, event, stop in
        if let action = action {
          self.removeAction(action, for: event)
        }
      }
      addAction(UIAction(handler: { _ in
        configuration.action()
      }), for: .touchUpInside)
      setNeedsLayout()
    }
    
    func prepareForReuse() {
      imageDownloadTask?.cancel()
      imageDownloadTask = nil
      imageView.image = nil
      nameLabel.text = nil
      collectiomNameLabel.text = nil
    }
  }
}

private extension HistoryCellActionView.NFTView {
  func setup() {
    isExclusiveTouch = true
    
    contentView.backgroundColor = .Bubble.background
    contentView.isUserInteractionEnabled = false
    
    contentView.layer.cornerRadius = .cornerRadius
    contentView.layer.masksToBounds = true
    
    highlightView.alpha = 1
    
    addSubview(contentView)
    contentView.addSubview(highlightView)
    contentView.addSubview(imageView)
    contentView.addSubview(nameLabel)
    contentView.addSubview(collectiomNameLabel)
  }
}

private extension CGFloat {
  static let topInset: CGFloat = 8
  static let cornerRadius: CGFloat = 12
  static let imageSize: CGFloat = 64
  static let width: CGFloat = 176
  static let height: CGFloat = 64
  static let labelsSideSpace: CGFloat = 12
}

private extension UIEdgeInsets {
  static let textContentPadding = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
}

