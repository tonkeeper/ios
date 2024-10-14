import UIKit

public typealias TKTitleDescriptionCellRegistration = UICollectionView.CellRegistration<TKTitleDescriptionCell, TKTitleDescriptionCell.Configuration>
public extension TKTitleDescriptionCellRegistration {
  static func registration(collectionView: UICollectionView) -> TKTitleDescriptionCellRegistration {
    TKTitleDescriptionCellRegistration { cell, indexPath, configuration in
      cell.configuration = configuration
    }
  }
}

public final class TKTitleDescriptionCell: UICollectionViewCell {
  
  public struct Configuration: Hashable {
    public let model: TKTitleDescriptionView.Model
    public let padding: NSDirectionalEdgeInsets
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(model)
    }
    
    public init(model: TKTitleDescriptionView.Model, 
                padding: NSDirectionalEdgeInsets) {
      self.model = model
      self.padding = padding
    }
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
      invalidateIntrinsicContentSize()
      setNeedsLayout()
    }
  }
  
  let view = TKTitleDescriptionView(size: .big)
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    contentView.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(contentView)
    }
  }
  
  private func didUpdateConfiguration() {
    guard let configuration else { return }
    view.configure(model: configuration.model)
    view.padding = configuration.padding
  }
}
