import UIKit

public final class TKTickView: UIView {
  
  public var isSelected: Bool = false {
    didSet {
      unselectedView.alpha = isSelected ? 0 : 1
      selectedView.alpha = isSelected ? 1 : 0
    }
  }
  
  private let unselectedView = UITickViewUnselectedView()
  private let selectedView = UITickViewSelectedView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    unselectedView.frame = bounds.insetBy(dx: .padding, dy: .padding)
    selectedView.frame = bounds.insetBy(dx: .padding, dy: .padding)
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: .side, height: .side)
  }
}

private extension TKTickView {
  func setup() {
    addSubview(unselectedView)
    addSubview(selectedView)
    
    unselectedView.alpha = 1
    selectedView.alpha = 0
  }
}

private class UITickViewUnselectedView: UIView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setup() {
    backgroundColor = .clear
    layer.cornerRadius = .cornerRadius
    layer.borderWidth = .unselectedBorderWidth
    layer.borderColor = UIColor.Background.contentTint.cgColor
  }
}

private class UITickViewSelectedView: UIView {
  private let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    imageView.tintColor = .Button.primaryForeground
    imageView.image = .TKUIKit.Icons.Size16.doneBold
    return imageView
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
    imageView.frame = bounds
  }
  
  func setup() {
    backgroundColor = .Button.primaryBackground
    layer.cornerRadius = .cornerRadius
    addSubview(imageView)
  }
}

private extension CGFloat {
  static let side: CGFloat = 28
  static let padding: CGFloat = 3
  static let cornerRadius: CGFloat = 6
  static let unselectedBorderWidth: CGFloat = 2
}
