import UIKit
import TKUIKit
import SnapKit

final class BatteryView: UIView {
  
  enum Size {
    case size24
    case size34
    case size44
    case size128
    
    var bodyImage: UIImage {
      switch self {
      case .size24:
        return .App.Battery.batteryBody24
      case .size34:
        return .App.Battery.batteryBody34
      case .size44:
        return .App.Battery.batteryBody44
      case .size128:
        return .App.Battery.batteryBody128
      }
    }
    
    var bodySize: CGSize {
      switch self {
      case .size24:
        return CGSize(width: 14, height: 24)
      case .size34:
        return CGSize(width: 20, height: 34)
      case .size44:
        return CGSize(width: 26, height: 44)
      case .size128:
        return CGSize(width: 68, height: 114)
      }
    }
    
    var flashImage: UIImage? {
      switch self {
      case .size24:
        return nil
      case .size34:
        return .TKUIKit.Icons.Size16.flash
      case .size44:
        return .TKUIKit.Icons.Size16.flash
      case .size128:
        return .TKUIKit.Icons.Size16.flash
      }
    }
    
    var flashSize: CGSize {
      switch self {
      case .size24:
        return .zero
      case .size34:
        return CGSize(width: 9, height: 13)
      case .size44:
        return CGSize(width: 9, height: 13)
      case .size128:
        return CGSize(width: 28, height: 40)
      }
    }
    
    var fillCornerRadius: CGFloat {
      switch self {
      case .size24:
        return 1.5
      case .size34:
        return 2
      case .size44:
        return 3.5
      case .size128:
        return 8
      }
    }
    
    var fillMaximumHeight: CGFloat {
      switch self {
      case .size24:
        return 18
      case .size34:
        return 25
      case .size44:
        return 34
      case .size128:
        return 88
      }
    }
    
    var fillViewInset: CGFloat {
      switch self {
      case .size24:
        return 2
      case .size34:
        return 3
      case .size44:
        return 3
      case .size128:
        return 8
      }
    }
  }
  
  enum State: Hashable {
    case fill(CGFloat)
    case emptyTinted
    case empty
  }
  
  var state: State = .empty {
    didSet {
      didUpdateState(animated: true)
    }
  }
  
  var padding: UIEdgeInsets = .zero {
    didSet {
      invalidateIntrinsicContentSize()
      contentView.snp.remakeConstraints { make in
        make.edges.equalTo(self).inset(padding)
      }
    }
  }
  
  private let bodyImageView = UIImageView()
  private let flashImageView = UIImageView()
  private let fillView = UIView()
  private let contentView = UIView()
  
  private var fillViewHeightConstraint: Constraint?
  
  private let size: Size
  
  init(size: Size) {
    self.size = size
    super.init(frame: CGRect(origin: .zero, size: size.bodySize))
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    let size = CGSize(width: size.bodySize.width + padding.left + padding.right,
                      height: size.bodySize.height + padding.top + padding.bottom)
    return size
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    intrinsicContentSize
  }
  
  private func setup() {
    bodyImageView.image = size.bodyImage
    flashImageView.image = size.flashImage
    fillView.layer.cornerRadius = size.fillCornerRadius
    
    addSubview(contentView)
    contentView.addSubview(bodyImageView)
    contentView.addSubview(flashImageView)
    contentView.addSubview(fillView)
    
    contentView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(padding)
    }
    
    bodyImageView.snp.makeConstraints { make in
      make.edges.equalTo(contentView)
    }
    flashImageView.snp.makeConstraints { make in
      make.size.equalTo(size.flashSize)
      make.centerX.equalTo(contentView)
      make.centerY.equalTo(contentView).offset(size.bodySize.height * 0.05)
    }
    fillView.snp.makeConstraints { make in
      make.bottom.equalTo(contentView).inset(size.fillViewInset)
      make.left.right.equalTo(contentView).inset(size.fillViewInset)
      fillViewHeightConstraint = make.height.equalTo(0).constraint
    }
    
    didUpdateState(animated: false)
  }
  
  private func didUpdateState(animated: Bool) {
    let duration: TimeInterval = animated ? 0.2 : 0
    updateFlash(duration: duration)
    updateFillView(duration: duration)
  }
  
  private func updateFlash(duration: TimeInterval) {
    let finalAlpha: CGFloat
    let color: UIColor
    switch state {
    case .fill:
      finalAlpha = 0
      color = .clear
    case .emptyTinted:
      finalAlpha = 1
      color = .Accent.blue
    case .empty:
      finalAlpha = 1
      color = .Icon.secondary
    }
    UIView.animate(
      withDuration: duration,
      delay: 0,
      options: .curveEaseInOut,
      animations: {
        self.flashImageView.alpha = finalAlpha
        self.flashImageView.tintColor = color
      }
    )
  }
  
  private func updateFillView(duration: TimeInterval) {
    let finalAlpha: CGFloat
    let color: UIColor
    let height: CGFloat
    switch state {
    case .fill(let fill):
      finalAlpha = 1
      height = size.fillMaximumHeight * min(1, max(fill, 0.2))
      color = fill <= 0.1 ? .Accent.orange : .Accent.blue
    case .emptyTinted:
      finalAlpha = 0
      height = 0
      color = .Accent.orange
    case .empty:
      finalAlpha = 0
      height = 0
      color = .Accent.orange
    }
    fillViewHeightConstraint?.update(offset: height)
    UIView.animate(
      withDuration: duration,
      delay: 0,
      options: .curveEaseOut,
      animations: {
        self.fillView.alpha = finalAlpha
        self.fillView.backgroundColor = color
        self.layoutIfNeeded()
      }
    )
  }
}
