import UIKit
import TKUIKit

final class ChooseWalletToAddCellContentView: UIView, ConfigurableView {
  let textContentView = TKListItemTextContentView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let textContenViewFittingSize = textContentView.systemLayoutSizeFitting(
      CGSize(width: bounds.width,
             height: 0)
    )
    let textContentViewSize = CGSize(
      width: min(bounds.width, textContenViewFittingSize.width),
      height: textContenViewFittingSize.height
    )
    
    textContentView.frame = CGRect(
      origin: CGPoint(x: 0, y: bounds.height/2 - textContentViewSize.height/2),
      size: textContentViewSize)
  }
  
  public override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
    let textContentFittingSize = textContentView.systemLayoutSizeFitting(
      CGSize(width: targetSize.width,
             height: targetSize.height)
    )
    let resultWidth = textContentFittingSize.width
    let resultHeight = textContentFittingSize.height
    return CGSize(width: resultWidth, height: resultHeight)
  }
  
  struct Model {
    public let textContentModel: TKListItemTextContentView.Model
    
    public init(textContentModel: TKListItemTextContentView.Model) {
      self.textContentModel = textContentModel
    }
  }
  
  func configure(model: Model) {
    textContentView.configure(model: model.textContentModel)
    setNeedsLayout()
  }
  
  private func setup() {
    addSubview(textContentView)
  }
}

final class ChooseWalletToAddCell: UICollectionViewCell, ConfigurableView {
  public var isFirstInSection: ((IndexPath) -> Bool) = { _ in false }
  public var isLastInSection: ((IndexPath) -> Bool) =  { _ in false }
  
  let cellContentView = ChooseWalletToAddCellContentView()
  let highlightView = TKHighlightView()
  let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  let tickView = TKTickView()
  
  private var isSeparatorVisible: Bool = false
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  public override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    
    let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
    let contentFrame = targetSize.inset(by: .contentPadding)
    
    let cellContentViewSize = cellContentView.systemLayoutSizeFitting(CGSize(width: contentFrame.width, height: 0))
    
    let resultSize = cellContentViewSize.padding(by: .contentPadding)
    modifiedAttributes.frame.size.height = resultSize.height
    
    let isFirstInSection = isFirstInSection(layoutAttributes.indexPath)
    let isLastInSection = isLastInSection(layoutAttributes.indexPath)
    setupCornerRadius(isFirstInSection: isFirstInSection, isLastInSection: isLastInSection)
    isSeparatorVisible = !isLastInSection
    setupSeparator()
    
    return modifiedAttributes
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    layoutTick()
    layoutCellContentView()
    layoutSeparator()
    highlightView.frame = bounds
  }
  
  struct Model: Hashable {
    let identifier: String
    let contentViewModel: ChooseWalletToAddCellContentView.Model
    
    static func == (lhs: Model, rhs: Model) -> Bool {
      lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
  }
  
  func configure(model: Model) {
    cellContentView.configure(model: model.contentViewModel)
  }
  
  override func updateConfiguration(using state: UICellConfigurationState) {
    highlightView.alpha = state.isHighlighted ? 1 : 0
    tickView.isSelected = state.isSelected
  }
}

private extension ChooseWalletToAddCell {
  func setup() {
    layer.cornerRadius = .cornerRadius
    backgroundColor = .Background.content
    
    highlightView.backgroundColor = .Background.highlighted
    highlightView.alpha = 0
    
    contentView.addSubview(highlightView)
    contentView.addSubview(cellContentView)
    contentView.addSubview(separatorView)
    
    addSubview(tickView)
  }
  
  func setupSeparator() {
    let isHidden = !isSeparatorVisible || configurationState.isHighlighted
    separatorView.isHidden = isHidden
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
  
  func layoutCellContentView() {
    let contentFrame = self.contentView.bounds.inset(by: .contentPadding)
    let cellContentViewFrame = CGRect(
      origin: contentFrame.origin,
      size: CGSize(width: contentFrame.width - tickView.frame.width, height: contentFrame.height)
    )
    cellContentView.frame = cellContentViewFrame
  }
  
  func layoutSeparator() {
    let contentFrame = contentView.bounds.inset(by: .contentPadding)
    let separatorViewFrame = CGRect(x: contentFrame.minX,
                                    y: bounds.height - 0.5,
                                    width: contentFrame.width + UIEdgeInsets.contentPadding.right,
                                    height: 0.5)
    separatorView.frame = separatorViewFrame
  }
  
  func layoutTick() {
    let contentFrame = self.contentView.bounds.inset(by: .contentPadding)
    let tickSize = tickView.intrinsicContentSize
    let tickFrame = CGRect(origin: CGPoint(x: contentFrame.maxX - tickSize.width, y: bounds.height/2 - tickSize.height/2),
                           size: tickSize)
    tickView.frame = tickFrame
  }
}

private extension UIEdgeInsets {
  static let contentPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
private extension CGFloat {
  static let cornerRadius: CGFloat = 16
}
