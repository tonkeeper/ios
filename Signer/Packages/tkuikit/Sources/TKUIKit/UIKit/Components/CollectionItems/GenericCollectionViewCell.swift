import UIKit

public protocol GenericCollectionViewCellContentView: ConfigurableView, ReusableView {
  var padding: NSDirectionalEdgeInsets { get }
}

public extension GenericCollectionViewCellContentView {
  var padding: NSDirectionalEdgeInsets {
    NSDirectionalEdgeInsets(
      top: 16,
      leading: 16,
      bottom: 16,
      trailing: 16)
  }
}

public final class GenericCollectionViewCell<CellContentView: GenericCollectionViewCellContentView>: UICollectionViewCell, ConfigurableView, ReusableView {
  
  public var isFirstCellInSection: ((IndexPath) -> Bool) = { _ in false }
  public var isLastCellInSection: ((IndexPath) -> Bool) = { _ in false }
  
  let cellContentView = CellContentView()
  
  private let highlightView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.highlighted
    view.alpha = 0
    return view
  }()
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  private let maskLayer = CAShapeLayer()
  
  public var isFirstInSection = false {
    didSet {
      setupCornerRadius()
      setupSeparator()
    }
  }
  
  public var isLastInSection = false {
    didSet {
      setupCornerRadius()
      setupSeparator()
    }
  }
  
  private var isSeparatorVisible = false {
    didSet {
      separatorView.isHidden = !isSeparatorVisible
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func updateConfiguration(using state: UICellConfigurationState) {
    automaticallyUpdatesBackgroundConfiguration = false
    UIView.animate(withDuration: 0.1) {
      self.highlightView.alpha = state.isHighlighted ? 1 : 0
      self.updateSeparatorVisibility()
    }
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    maskLayer.frame = bounds
    layer.mask = maskLayer
    cellContentView.frame = contentView.bounds
      .inset(by: .init(
        top: cellContentView.padding.top,
        left: cellContentView.padding.leading,
        bottom: cellContentView.padding.bottom,
        right: cellContentView.padding.trailing)
      )
    highlightView.frame = contentView.bounds
    separatorView.frame = CGRect(
      x: cellContentView.padding.leading,
      y: bounds.height - .separatorHeight,
      width: bounds.width - cellContentView.padding.trailing,
      height: .separatorHeight)
    setupCornerRadius()
  }
  
  public override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
    let width = targetSize.width - (cellContentView.padding.leading + cellContentView.padding.trailing)
    let cellContentViewSize = cellContentView.sizeThatFits(.init(width: width, height: 0))
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    modifiedAttributes.frame.size.height = cellContentViewSize.height + (cellContentView.padding.top + cellContentView.padding.bottom)
    modifiedAttributes.frame.size.width = cellContentViewSize.width
    
    isFirstInSection = isFirstCellInSection(layoutAttributes.indexPath)
    isLastInSection = isLastCellInSection(layoutAttributes.indexPath)
    setupSeparator()
    updateSeparatorVisibility()
    
    return modifiedAttributes
  }
  
  // MARK: - ConfigurableView
  
  public func configure(model: CellContentView.Model) {
    cellContentView.configure(model: model)
  }
}

private extension GenericCollectionViewCell {
  func setup() {
    backgroundColor = .Background.content
    contentView.addSubview(highlightView)
    contentView.addSubview(cellContentView)
    contentView.addSubview(separatorView)
    updateSeparatorVisibility()
  }
  
  func setupCornerRadius() {
    let roundingCorners: UIRectCorner
    
    switch (isFirstInSection, isLastInSection) {
    case (true, true):
      roundingCorners = [.allCorners]
    case (true, false):
      roundingCorners = [.topLeft, .topRight]
    case (false, true):
      roundingCorners = [.bottomLeft, .bottomRight]
    case (false, false):
      roundingCorners = []
    }

    let path = UIBezierPath(
      roundedRect: bounds,
      byRoundingCorners: roundingCorners,
      cornerRadii: CGSize(width: .cornerRadius, height: .cornerRadius)
    )
    maskLayer.path = path.cgPath
  }
  
  func setupSeparator() {
    switch (isFirstInSection, isLastInSection) {
    case (true, false):
      isSeparatorVisible = true
    case (false, false):
      isSeparatorVisible = true
    default:
      isSeparatorVisible = false
    }
  }
  
  func updateSeparatorVisibility() {
    self.separatorView.alpha = !configurationState.isHighlighted && self.isSeparatorVisible ? 1 : 0
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let separatorHeight: CGFloat = 0.5
}
