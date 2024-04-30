import UIKit

final class TKListItemCollectionViewCellAccessoryView: UIView {
  enum Mode {
    case none
    case checkmark
    case disclosureIndicator
    case reorder
    
    var image: UIImage? {
      switch self {
      case .none: return nil
      case .checkmark: return .TKUIKit.Icons.Size28.donemarkOutline
      case .disclosureIndicator: return .TKUIKit.Icons.Size16.chevronRight
      case .reorder: return .TKUIKit.Icons.Size28.reorder
      }
    }
    
    var tintColor: UIColor? {
      switch self {
      case .none: return nil
      case .checkmark: return .Accent.blue
      case .disclosureIndicator: return .Icon.tertiary
      case .reorder: return .Icon.secondary
      }
    }
    
    var width: CGFloat {
      switch self {
      case .none: return 0
      case .checkmark: return 28
      case .disclosureIndicator: return 16
      case .reorder: return 28
      }
    }
    
    var leftPadding: CGFloat {
      switch self {
      case .none: return 0
      case .checkmark: return .leftPadding
      case .disclosureIndicator: return .leftPadding
      case .reorder: return .leftPadding
      }
    }
  }
  
  var mode: Mode {
    didSet {
      setupMode()
    }
  }
  
  private let imageView = UIImageView()
  
  init(mode: Mode) {
    self.mode = mode
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    imageView.frame = CGRect(x: mode.leftPadding, y: 0, width: bounds.width - mode.leftPadding, height: bounds.height)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return CGSize(width: mode.width + mode.leftPadding, height: size.height)
  }
}

private extension TKListItemCollectionViewCellAccessoryView {
  func setup() {
    imageView.contentMode = .left
    addSubview(imageView)
    setupMode()
  }
  
  func setupMode() {
    imageView.image = mode.image
    imageView.tintColor = mode.tintColor
    setNeedsLayout()
  }
}

private extension CGFloat {
  static let leftPadding: CGFloat = 16
}
