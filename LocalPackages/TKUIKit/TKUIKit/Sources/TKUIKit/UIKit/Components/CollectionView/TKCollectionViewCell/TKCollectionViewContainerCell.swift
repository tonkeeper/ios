import UIKit

public protocol TKCollectionViewCellContentView: UIView, ReusableView, ConfigurableView {
  var padding: UIEdgeInsets { get }
}

open class TKCollectionViewContainerCell<CellContentView: TKCollectionViewCellContentView>: TKCollectionViewCell {
  
  // MARK: - Subviews
  
  public let cellContentView = CellContentView()

  // MARK: - Init
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  public class Model: Hashable {
    public let identifier: String
    public let isHighlightable: Bool
    public let isSelectable: Bool
    public let accessoryType: AccessoryType
    public let selectionHandler: (() -> Void)?
    public let cellContentModel: CellContentView.Model
    
    public init(identifier: String, 
                isHighlightable: Bool = true,
                isSelectable: Bool = false,
                accessoryType: AccessoryType = .none,
                selectionHandler: (() -> Void)? = nil,
                cellContentModel: CellContentView.Model) {
      self.identifier = identifier
      self.isHighlightable = isHighlightable
      self.isSelectable = isSelectable
      self.accessoryType = accessoryType
      self.selectionHandler = selectionHandler
      self.cellContentModel = cellContentModel
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
    
    public static func == (lhs: Model, rhs: Model) -> Bool {
      lhs.identifier == rhs.identifier
    }
  }
  
  public func configure(model: Model) {
    cellContentView.configure(model: model.cellContentModel)
    self.isSelectable = model.isSelectable
    self.accessoryType = model.accessoryType
    setNeedsLayout()
  }
  
  // MARK: - Reuse
  
  open override func prepareForReuse() {
    super.prepareForReuse()
    cellContentView.prepareForReuse()
  }
  
  // MARK: - Layout
  
  open override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    
    let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
    let contentFrame = targetSize.inset(by: cellContentView.padding)
    
    let cellContentViewSize = cellContentView.sizeThatFits(CGSize(width: contentFrame.width, height: 0))
    
    let resultSize = cellContentViewSize.padding(by: cellContentView.padding)
    modifiedAttributes.frame.size = resultSize
    
    return modifiedAttributes
  }
  
  open override func layoutSubviews() {
    super.layoutSubviews()
    
    layoutCellContentView()
  }
  
  open override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)
    layoutCellContentView()
  }
  
  override func setup() {
    super.setup()
    contentViewPadding = cellContentView.padding
    contentContainer.addSubview(cellContentView)
  }
}

extension TKCollectionViewContainerCell {
  
  // MARK: - Layout
  
  func layoutCellContentView() {
    cellContentView.frame = contentContainer.bounds
    cellContentView.setNeedsLayout()
    cellContentView.layoutIfNeeded()
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
}

