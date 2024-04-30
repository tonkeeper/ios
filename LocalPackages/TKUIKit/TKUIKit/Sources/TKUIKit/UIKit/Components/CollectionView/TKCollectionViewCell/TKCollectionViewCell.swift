import UIKit

open class TKCollectionViewCell: UICollectionViewCell, ReusableView {
  
  public enum AccessoryType {
    case none
    case disclosureIndicator
  }
  
  public var isFirstInSection: ((IndexPath) -> Bool) = { _ in false }
  public var isLastInSection: ((IndexPath) -> Bool) =  { _ in false }
  
  public var contentViewPadding: UIEdgeInsets = .zero {
    didSet {
      setNeedsLayout()
    }
  }
  
  public var separatorLeftPadding: CGFloat = 16 {
    didSet {
      layoutSeparator()
    }
  }
  
  public var isSelectable: Bool = true {
    didSet {
      updateConfiguration(using: configurationState)
    }
  }
  
  public var accessoryType: AccessoryType = .none {
    didSet {
      setupAccessoryView()
    }
  }
  
  public var isSeparatorEnabled: Bool = true
    
  // MARK: - Subviews
  
  let highlightView = TKHighlightView()
  let contentContainer = UIView()
  
  let separatorView: UIView = {
    let view = TKSeparatorView()
    view.color = .Separator.common
    return view
  }()
  let accessoryView = TKListItemCollectionViewCellAccessoryView(mode: .none)
  let editingAccessoryView = TKListItemCollectionViewCellAccessoryView(mode: .reorder)
  let selectionAccessoryView = TKListItemCollectionViewCellAccessoryView(mode: .checkmark)
  
  private var isSeparatorVisible: Bool = false
  
  // MARK: - Init
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  open override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let isFirstInSection = isFirstInSection(layoutAttributes.indexPath)
    let isLastInSection = isLastInSection(layoutAttributes.indexPath)
    setupCornerRadius(isFirstInSection: isFirstInSection, isLastInSection: isLastInSection)
    isSeparatorVisible = !isLastInSection
    setupSeparator()
    
    return layoutAttributes
  }
  
  open override func layoutSubviews() {
    super.layoutSubviews()
    
    highlightView.frame = bounds
    layoutSeparator()
    layoutContentContainer()
    layoutAccessoryView()
    layoutEditingAccessoryView()
    layoutSelectionAccessoryView()
  }
  
  open override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)
    highlightView.alpha = state.isHighlighted ? 1 : 0
    
    editingAccessoryView.alpha = state.isEditing ? 1 : 0
    selectionAccessoryView.alpha = state.isSelected && isSelectable ? 1 : 0
    accessoryView.alpha = !state.isEditing && !(state.isSelected && isSelectable) && accessoryType != .none ? 1 : 0
    
    layoutContentContainer()
    setupSeparator()
  }
  
  func setup() {
    layer.cornerRadius = .cornerRadius
    
    highlightView.backgroundColor = .Background.highlighted
    highlightView.alpha = 0
    
    setupAccessoryView()
    contentView.addSubview(highlightView)
    contentView.addSubview(separatorView)
    contentView.addSubview(contentContainer)
    contentView.addSubview(accessoryView)
    contentView.addSubview(editingAccessoryView)
    contentView.addSubview(selectionAccessoryView)
  }
}

extension TKCollectionViewCell {

  // MARK: - Setup
  
  func setupSeparator() {
    let isHidden = !isSeparatorVisible || configurationState.isHighlighted || !isSeparatorEnabled
    separatorView.isHidden = isHidden
  }
  
  // MARK: - Layout
  
  func layoutSeparator() {
    let separatorViewFrame = CGRect(x: separatorLeftPadding,
                                    y: bounds.height - TKUIKit.Constants.separatorWidth,
                                    width: bounds.width - separatorLeftPadding,
                                    height: TKUIKit.Constants.separatorWidth)
    separatorView.frame = separatorViewFrame
  }
  
  func layoutContentContainer() {
    let contentFrame = self.contentView.bounds.inset(by: contentViewPadding)
    let accessoryWidth: CGFloat
    switch (configurationState.isEditing, configurationState.isSelected && isSelectable) {
    case (true, _):
      accessoryWidth = editingAccessoryView.bounds.width
    case (false, true):
      accessoryWidth = selectionAccessoryView.bounds.width
    case (false, false):
      accessoryWidth = accessoryView.sizeThatFits(CGSize(width: 0, height: bounds.height)).width
    }
    let contentContainerFrame = CGRect(
      origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY),
      size: CGSize(width: contentFrame.width - accessoryWidth, height: contentFrame.height)
    )
    contentContainer.frame = contentContainerFrame
  }
  
  func layoutEditingAccessoryView() {
    let frame = contentView.bounds.inset(by: contentViewPadding)
    let accessoryWidth = editingAccessoryView.sizeThatFits(.zero).width
    let accessoryFrame = CGRect(
      origin: CGPoint(x: frame.maxX - accessoryWidth, y: frame.minY),
      size: CGSize(width: accessoryWidth, height: frame.height)
    )
    editingAccessoryView.frame = accessoryFrame
  }
  
  func layoutSelectionAccessoryView() {
    let frame = contentView.bounds.inset(by: contentViewPadding)
    let accessoryWidth = selectionAccessoryView.sizeThatFits(.zero).width
    let accessoryFrame = CGRect(
      origin: CGPoint(x: frame.maxX - accessoryWidth, y: frame.minY),
      size: CGSize(width: accessoryWidth, height: frame.height)
    )
    selectionAccessoryView.frame = accessoryFrame
  }
  
  func layoutAccessoryView() {
    let frame = contentView.bounds.inset(by: contentViewPadding)
    let accessoryWidth = accessoryView.sizeThatFits(.zero).width
    let accessoryFrame = CGRect(
      origin: CGPoint(x: frame.maxX - accessoryWidth, y: frame.minY),
      size: CGSize(width: accessoryWidth, height: frame.height)
    )
    accessoryView.frame = accessoryFrame
  }

  func setupCornerRadius(isFirstInSection: Bool, isLastInSection: Bool) {
    let maskedCorners: CACornerMask
    let isMasksToBounds: Bool
    switch (isFirstInSection, isLastInSection) {
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
  
  func setupAccessoryView() {
    switch accessoryType {
    case .none:
      accessoryView.mode = .none
    case .disclosureIndicator:
      accessoryView.mode = .disclosureIndicator
    }
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
}

