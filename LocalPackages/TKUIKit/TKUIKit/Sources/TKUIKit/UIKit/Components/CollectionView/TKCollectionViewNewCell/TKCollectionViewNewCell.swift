import UIKit

public protocol OrderConfigurableCell: UICollectionViewCell {
  var isFirstInSection: ((IndexPath) -> Bool) { get set }
  var isLastInSection: ((IndexPath) -> Bool) { get set }
}

open class TKCollectionViewNewCell: UICollectionViewCell, OrderConfigurableCell, ReusableView {
  
  public var isFirstInSection: ((IndexPath) -> Bool) = { _ in false }
  public var isLastInSection: ((IndexPath) -> Bool) = { _ in false }
    
  public var hightlightColor: UIColor = .clear
  public var separatorColor: UIColor = .Separator.common {
    didSet { separatorView.color = separatorColor }
  }
  
  public var contentViewPadding: UIEdgeInsets = .zero {
    didSet { didUpdateContentViewPadding() }
  }
  
  public var accessoryViews = [UIView]() {
    didSet { didUpdateAccessoryViews() }
  }
  public var selectionAccessoryViews = [UIView]() {
    didSet { didUpdateSelectionAccessoryViews()}
  }
  public var editingAccessoryViews = [UIView]() {
    didSet { didUpdateEditingAccessoryViews() }
  }
  public var isSeparatorVisible: Bool = true {
    didSet { updateSeparatorVisibility() }
  }
  public var isHighlightable: Bool = true
  
  public let contentContainerView = TKPassthroughView()
  
  private let hightlightView = UIView()
  private let separatorView = TKSeparatorView()
  private let accessoryContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.alignment = .center
    return stackView
  }()
  private let selectionAccessoryContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.alignment = .center
    return stackView
  }()
  private let editingAccessoryContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.alignment = .center
    return stackView
  }()
  
  private var isFirstCellInSection: Bool = false {
    didSet { didUpdateCellOrderParameter() }
  }
  
  private var isLastCellInSection: Bool = false {
    didSet { didUpdateCellOrderParameter() }
  }

  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)
    
    hightlightView.backgroundColor = state.isHighlighted && isHighlightable ? hightlightColor : .clear
    UIView.performWithoutAnimation {
      setNeedsLayout()
      layoutIfNeeded()
      updateAccessoryContainersVisibility()
      layoutEditingAccessoryContainer()
      layoutSelectionAccessoryContainer()
      setNeedsLayout()
      layoutIfNeeded()
    }
    updateAccessoryContainersAlpha()
    updateSeparatorVisibility()
  }
  
  open override func layoutSubviews() {
    super.layoutSubviews()
    hightlightView.frame = contentView.bounds
    separatorView.frame = CGRect(
      x: contentViewPadding.left,
      y: bounds.height - TKUIKit.Constants.separatorWidth,
      width: bounds.width - contentViewPadding.left,
      height: TKUIKit.Constants.separatorWidth
    )
    layoutContentContainer()
  }
  
  open override func preferredLayoutAttributesFitting(
    _ layoutAttributes: UICollectionViewLayoutAttributes
  ) -> UICollectionViewLayoutAttributes {
    guard let modifiedAttributes = layoutAttributes.copy() as? UICollectionViewLayoutAttributes else {
      return layoutAttributes
    }
    let accessoryViewWidth = accessoryContainer.systemLayoutSizeFitting(.zero).width
    let targetWidth = modifiedAttributes.frame.width - contentViewPadding.left - contentViewPadding.right - accessoryViewWidth
    let contentViewSize = contentSize(targetWidth: targetWidth)

    let resultHeight = contentViewSize.height + contentViewPadding.top + contentViewPadding.bottom
    let resultSize = CGSize(width: modifiedAttributes.frame.width, height: resultHeight)
    modifiedAttributes.frame.size = resultSize
    
    isFirstCellInSection = isFirstInSection(layoutAttributes.indexPath)
    isLastCellInSection = isLastInSection(layoutAttributes.indexPath)
    
    return modifiedAttributes
  }
  
  open func contentSize(targetWidth: CGFloat) -> CGSize {
    .zero
  }
}

private extension TKCollectionViewNewCell {
  var contentContainerDefaultStateFrame: CGRect {
    let size = CGSize(
      width: contentView.bounds.width - accessoryContainer.bounds.width,
      height: contentView.bounds.height
    )
    return CGRect(origin: .zero, size: size)
  }
  
  var contentContainerEditingStateFrame: CGRect {
    let size = CGSize(
      width: contentView.bounds.width - editingAccessoryContainer.bounds.width,
      height: contentView.bounds.height
    )
    return CGRect(origin: .zero, size: size)
  }
  
  var contentContainerSelectionStateFrame: CGRect {
    let size = CGSize(
      width: contentView.bounds.width - selectionAccessoryContainer.bounds.width,
      height: contentView.bounds.height
    )
    return CGRect(origin: .zero, size: size)
  }
  
  func setup() {
    contentView.addSubview(hightlightView)
    contentView.addSubview(contentContainerView)
    contentView.addSubview(accessoryContainer)
    contentView.addSubview(selectionAccessoryContainer)
    contentView.addSubview(editingAccessoryContainer)
    contentView.addSubview(separatorView)
    
    separatorView.color = separatorColor
    
    layer.cornerRadius = 16
  }

  func layoutSelectionAccessoryContainer() {
    guard !selectionAccessoryContainer.arrangedSubviews.isEmpty else { return }
    let sizeFitting = selectionAccessoryContainer.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    let size = CGSize(width: sizeFitting.width, height: contentView.bounds.height)
    let origin = CGPoint(
      x: contentView.bounds.width - sizeFitting.width,
      y: contentView.bounds.height/2 - size.height/2
    )
    selectionAccessoryContainer.frame = CGRect(
      origin: origin,
      size: size
    )
  }
  
  func layoutEditingAccessoryContainer() {
    guard !editingAccessoryContainer.arrangedSubviews.isEmpty else { return }
    let sizeFitting = editingAccessoryContainer.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    let size = CGSize(width: sizeFitting.width, height: contentView.bounds.height)
    let origin = CGPoint(
      x: contentView.bounds.width - sizeFitting.width,
      y: contentView.bounds.height/2 - size.height/2
    )
    editingAccessoryContainer.frame = CGRect(
      origin: origin,
      size: size
    )
  }
  
  func layoutAccessoryContainer() {
    guard !accessoryContainer.arrangedSubviews.isEmpty else { return }
    let sizeFitting = accessoryContainer.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    let size = CGSize(width: sizeFitting.width, height: contentView.bounds.height)
    let origin = CGPoint(
      x: contentView.bounds.width - sizeFitting.width,
      y: contentView.bounds.height/2 - size.height/2
    )
    accessoryContainer.frame = CGRect(
      origin: origin,
      size: size
    )
  }
  
  func layoutContentContainer() {
    switch (configurationState.isEditing, configurationState.isSelected) {
    case (true, _):
      layoutContentContainerEditingState()
    case (false, true):
      layoutContentContainerSelectionState()
    case (false, false):
      layoutContentContainerDefaultState()
    }
  }
  
  func layoutContentContainerEditingState() {
    let frame = contentContainerEditingStateFrame.inset(by: contentViewPadding)
    contentContainerView.frame = frame
  }
  
  func layoutContentContainerSelectionState() {
    let frame = contentContainerSelectionStateFrame.inset(by: contentViewPadding)
    contentContainerView.frame = frame
  }
  
  func layoutContentContainerDefaultState() {
    let frame = contentContainerDefaultStateFrame.inset(by: contentViewPadding)
    contentContainerView.frame = frame
  }
  
  func didUpdateContentViewPadding() {
    setNeedsLayout()
  }
  
  func didUpdateAccessoryViews() {
    accessoryContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
    accessoryViews.forEach {
      accessoryContainer.addArrangedSubview($0)
    }
    layoutAccessoryContainer()
    layoutContentContainer()
  }
  
  func didUpdateSelectionAccessoryViews() {
    selectionAccessoryContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
    selectionAccessoryViews.forEach {
      selectionAccessoryContainer.addArrangedSubview($0)
    }
    layoutSelectionAccessoryContainer()
    layoutContentContainer()
  }
  
  func didUpdateEditingAccessoryViews() {
    editingAccessoryContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
    editingAccessoryViews.forEach {
      editingAccessoryContainer.addArrangedSubview($0)
    }
    layoutEditingAccessoryContainer()
    layoutContentContainer()
  }
  
  func updateSeparatorVisibility() {
    let isVisible = isSeparatorVisible && !configurationState.isHighlighted && !isLastCellInSection && !configurationState.isReordering
    separatorView.isHidden = !isVisible
  }
  
  func updateAccessoryContainersVisibility() {
    switch (configurationState.isEditing, configurationState.isSelected) {
    case (true, _):
      editingAccessoryContainer.isHidden = false
      selectionAccessoryContainer.isHidden = true
      accessoryContainer.isHidden = true
    case (false, true):
      editingAccessoryContainer.isHidden = true
      selectionAccessoryContainer.isHidden = false
      accessoryContainer.isHidden = true
    case (false, false):
      editingAccessoryContainer.isHidden = true
      selectionAccessoryContainer.isHidden = true
      accessoryContainer.isHidden = false
    }
  }
  
  func updateAccessoryContainersAlpha() {
    switch (configurationState.isEditing, configurationState.isSelected) {
    case (true, _):
      editingAccessoryContainer.alpha = 1
      selectionAccessoryContainer.alpha = 0
      accessoryContainer.alpha = 0
    case (false, true):
      editingAccessoryContainer.alpha = 0
      selectionAccessoryContainer.alpha = 1
      accessoryContainer.alpha = 0
    case (false, false):
      editingAccessoryContainer.alpha = 0
      selectionAccessoryContainer.alpha = 0
      accessoryContainer.alpha = 1
    }
  }
  
  func didUpdateCellOrderParameter() {
    updateSeparatorVisibility()
    updateCornerRadius()
  }
  
  func updateCornerRadius() {
    let maskedCorners: CACornerMask
    let isMasksToBounds: Bool
    switch (isFirstCellInSection, isLastCellInSection) {
    case (true, true):
      maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
      isMasksToBounds = true
    case (false, true):
      maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
      isMasksToBounds = true
    case (true, false):
      maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
      isMasksToBounds = true
    case (false, false):
      maskedCorners = []
      isMasksToBounds = false
    }
    layer.maskedCorners = maskedCorners
    layer.masksToBounds = isMasksToBounds
  }
}

public class TKSeparatorView: UIView {

  public var color: UIColor = .Separator.common {
    didSet {
      setNeedsDisplay()
    }
  }
  
  public override var frame: CGRect {
    didSet {
      setNeedsDisplay()
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func draw(_ rect: CGRect) {
    let context = UIGraphicsGetCurrentContext()
    context?.setLineWidth(0.5)
    context?.move(to: CGPoint(x: 0, y: bounds.height))
    context?.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
    context?.setStrokeColor(color.cgColor)
    context?.strokePath()
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 1)
  }
}
