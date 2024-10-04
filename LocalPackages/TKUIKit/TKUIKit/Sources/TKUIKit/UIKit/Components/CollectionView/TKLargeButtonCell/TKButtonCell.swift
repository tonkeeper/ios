import UIKit

public final class TKButtonCell: UICollectionViewCell, ConfigurableView {
  
  private let button = TKButton()

  private let container = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model: Hashable {
    public enum Mode {
      case widthToFit
      case full
    }
    
    public let id: String
    public let configuration: TKButton.Configuration
    public let padding: UIEdgeInsets
    public let mode: Mode
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
    
    public static func ==(lhs: Model, rhs: Model) -> Bool {
      return lhs.id == rhs.id
    }
    
    public init(id: String,
                configuration: TKButton.Configuration,
                padding: UIEdgeInsets,
                mode: Mode) {
      self.id = id
      self.configuration = configuration
      self.padding = padding
      self.mode = mode
    }
  }
  
  public func configure(model: Model) {
    button.configuration = model.configuration
    container.snp.remakeConstraints { make in
      make.edges.equalTo(self).inset(model.padding)
    }
    button.snp.remakeConstraints { make in
      make.top.bottom.equalTo(container)
      switch model.mode {
      case .widthToFit:
        make.centerX.equalTo(container)
        make.left.greaterThanOrEqualTo(container)
        make.right.lessThanOrEqualTo(container)
      case .full:
        make.left.equalTo(container)
        make.right.equalTo(container)
      }
    }
  }
}

private extension TKButtonCell {
  func setup() {
    addSubview(container)
    container.addSubview(button)
    
    container.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    button.snp.makeConstraints { make in
      make.top.bottom.equalTo(container)
      make.centerX.equalTo(container)
      make.left.greaterThanOrEqualTo(container)
      make.right.lessThanOrEqualTo(container)
    }
  }
}
