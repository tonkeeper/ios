import UIKit

open class TKCollectionViewListCell: UICollectionViewCell {
  
  public var isFirstInSection: ((IndexPath) -> Bool) = { _ in return false }
  public var isLastInSection: ((IndexPath) -> Bool) = { _ in return false }
  
  public var listCellContentViewPadding: UIEdgeInsets = .zero {
    didSet {
      setNeedsLayout()
    }
  }
  
  public var defaultAccessoryViews: [UIView] {
    get { defaultAccessoryContainerView.accessoryViews }
    set { defaultAccessoryContainerView.accessoryViews = newValue }
  }
  
  public var selectionAccessoryViews: [UIView] {
    get { selectionAccessoryContainerView.accessoryViews }
    set { selectionAccessoryContainerView.accessoryViews = newValue }
  }
  
  public var editingAccessoryViews: [UIView] {
    get { editingAccessoryContainerView.accessoryViews }
    set { editingAccessoryContainerView.accessoryViews = newValue }
  }
  
  public var leftAccessoryViews: [UIView] {
    get { leftAccessoryContainerView.accessoryViews }
    set { leftAccessoryContainerView.accessoryViews = newValue }
  }
  
  public var highlightView: UIView? {
    didSet {
      oldValue?.removeFromSuperview()
      guard let highlightView else { return }
      highlightViewContainer.addSubview(highlightView)
      setNeedsLayout()
    }
  }
  
  private let highlightViewContainer = UIView()
  private let listCellContentContainerView = UIView()
  private let defaultAccessoryContainerView = TKCollectionViewListCellAccessoryContainerView()
  private let selectionAccessoryContainerView = TKCollectionViewListCellAccessoryContainerView()
  private let editingAccessoryContainerView = TKCollectionViewListCellAccessoryContainerView()
  private let leftAccessoryContainerView = TKCollectionViewListCellAccessoryContainerView()
  private let separatorView = TKSeparatorView()
  
  var listCellContentView: UIView?
  private var visibleAccessoryView: UIView?
  
  private var isFirst = false
  private var isLast = false
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func setContentView(_ contentView: UIView?) {
    listCellContentView?.removeFromSuperview()
    guard let contentView else { return }
    listCellContentView = contentView
    listCellContentContainerView.addSubview(contentView)
    setNeedsLayout()
  }
  
  open override func layoutSubviews() {
    super.layoutSubviews()
    highlightViewContainer.frame = contentView.bounds
    layoutContentView()
    layoutAccessoryView()
    layoutLeftAccessoryView()
    layoutSeparator()
  }
  
  open override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    
    isFirst = isFirstInSection(layoutAttributes.indexPath)
    isLast = isLastInSection(layoutAttributes.indexPath)
    
    didUpdateCellOrderInSection()
    
    guard let modifiedAttributes = layoutAttributes.copy() as? UICollectionViewLayoutAttributes else {
      return layoutAttributes
    }
    
    let defaultAccessoryContainerViewSizeThatFits = defaultAccessoryContainerView.sizeThatFits(
      CGSize(width: bounds.width, height: 0)
    )
    let leftAccessoryContainerViewSizeThatFits = leftAccessoryContainerView.sizeThatFits(
      CGSize(width: bounds.width - defaultAccessoryContainerViewSizeThatFits.width, height: 0)
    )
    let targetWidth = bounds.width
    - defaultAccessoryContainerViewSizeThatFits.width
    - leftAccessoryContainerViewSizeThatFits.width
    - listCellContentViewPadding.left
    - listCellContentViewPadding.right
    let contentViewHeightThatFits = listCellContentView?.sizeThatFits(CGSize(width: targetWidth, height: 0)).height ?? 0
    
    let resultHeight = contentViewHeightThatFits + listCellContentViewPadding.top + listCellContentViewPadding.bottom
    modifiedAttributes.frame.size.height = resultHeight
    
    return modifiedAttributes
  }
  
  open override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)
    
    highlightViewContainer.alpha = state.isHighlighted ? 1 : 0
    updateAccessoryView(state: state)
    
    UIView.performWithoutAnimation {
      layoutContentView()
      layoutAccessoryView()
      layoutLeftAccessoryView()
    }
    updateAccessoryViewVisibility()
    didUpdateCellOrderInSection()
  }
  
  open func didUpdateCellOrderInSection() {
    updateSeparatorVisibility()
  }
  
  private func setup() {
    updateAccessoryViewVisibility()
    highlightViewContainer.alpha = 0
    
    visibleAccessoryView = defaultAccessoryContainerView
    
    contentView.addSubview(highlightViewContainer)
    contentView.addSubview(listCellContentContainerView)
    contentView.addSubview(defaultAccessoryContainerView)
    contentView.addSubview(selectionAccessoryContainerView)
    contentView.addSubview(editingAccessoryContainerView)
    contentView.addSubview(leftAccessoryContainerView)
    contentView.addSubview(separatorView)
  }
  
  private func updateAccessoryView(state: UICellConfigurationState) {
    switch (state.isEditing, state.isSelected) {
    case (true, _):
      visibleAccessoryView = editingAccessoryContainerView
    case (false, true):
      visibleAccessoryView = selectionAccessoryContainerView
    case (false, false):
      visibleAccessoryView = defaultAccessoryContainerView
    }
  }
  
  private func updateAccessoryViewVisibility() {
    [defaultAccessoryContainerView, selectionAccessoryContainerView, editingAccessoryContainerView].forEach {
      $0.alpha = $0 == visibleAccessoryView ? 1 : 0
    }
  }
  
  private func updateSeparatorVisibility() {
    let isHidden = isLast || configurationState.isHighlighted || configurationState.isReordering
    separatorView.isHidden = isHidden
  }
  
  private func layoutContentView() {
    let contentViewFrame = getContentViewFrame()
    listCellContentContainerView.frame = contentViewFrame
    listCellContentView?.frame = listCellContentContainerView.bounds
  }
  
  private func layoutAccessoryView() {
    let frame = getAccessoryViewFrame()
    visibleAccessoryView?.frame = frame
    visibleAccessoryView?.setNeedsLayout()
    visibleAccessoryView?.layoutIfNeeded()
  }
  
  private func layoutLeftAccessoryView() {
    let frame = getLeftAccessoryViewFrame()
    leftAccessoryContainerView.frame = frame
    leftAccessoryContainerView.setNeedsLayout()
    leftAccessoryContainerView.layoutIfNeeded()
  }
  
  private func layoutSeparator() {
    separatorView.frame = CGRect(origin: CGPoint(x: 16, y: bounds.height - TKUIKit.Constants.separatorWidth),
                                 size: CGSize(width: bounds.width - 16, height: TKUIKit.Constants.separatorWidth))
  }
  
  private func getAccessoryViewFrame() -> CGRect {
    guard let visibleAccessoryView else {
      return CGRect(x: contentView.bounds.width, y: 0, width: 0, height: 0)
    }
    let accessoryViewSizeToFits = visibleAccessoryView.sizeThatFits(contentView.bounds.size)
    return CGRect(x: contentView.bounds.width - accessoryViewSizeToFits.width,
                  y: 0,
                  width: accessoryViewSizeToFits.width,
                  height: contentView.bounds.height)
  }
  
  private func getLeftAccessoryViewFrame() -> CGRect {
    let accessoryViewFrame = getAccessoryViewFrame()
    let size = CGSize(width: contentView.bounds.width - accessoryViewFrame.width, height: contentView.bounds.height)
    let leftAccessoryViewSizeToFits = leftAccessoryContainerView.sizeThatFits(size)
    return CGRect(x: 0,
                  y: 0,
                  width: leftAccessoryViewSizeToFits.width,
                  height: contentView.bounds.height)
  }
  
  private func getContentViewFrame() -> CGRect {
    let accessoryViewFrame = getAccessoryViewFrame()
    let leftAccessoryViewFrame = getLeftAccessoryViewFrame()
    
    let contentContainerViewWidth = bounds.width 
    - listCellContentViewPadding.left
    - listCellContentViewPadding.right
    - accessoryViewFrame.width
    - leftAccessoryViewFrame.width
    let contentContainerViewHeight = bounds.height - listCellContentViewPadding.top - listCellContentViewPadding.bottom
    let contentContainerViewFrame = CGRect(
      origin: CGPoint(x: leftAccessoryViewFrame.maxX + listCellContentViewPadding.left, y: listCellContentViewPadding.top),
      size: CGSize(width: contentContainerViewWidth, height: contentContainerViewHeight)
    )
    return contentContainerViewFrame
  }
}
