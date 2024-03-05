import UIKit
import TKUIKit
import SnapKit

final class SendPickerCell: UICollectionViewCell, ReusableView, ConfigurableView {
  
  var didTapAmount: (() -> Void)?
  
  private let highlightView = TKHighlightView()
  let informationView = InformationView()
  private let rightView = RightView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func updateConfiguration(using state: UICellConfigurationState) {
    highlightView.isHighlighted = state.isHighlighted
  }
  
  struct Model: Hashable, Identifiable {
    let id: String
    let informationModel: InformationView.Model
    let rightView: RightView.Model
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
    
    static func ==(lhs: Model, rhs: Model) -> Bool {
      lhs.id == rhs.id
    }
  }
  
  func configure(model: Model) {
    informationView.configure(model: model.informationModel)
    rightView.configure(model: model.rightView)
  }
  
  private func setup() {
    layer.cornerRadius = 16
    layer.masksToBounds = true
    backgroundColor = .Background.content
    
    contentView.addSubview(highlightView)
    contentView.addSubview(informationView)
    contentView.addSubview(rightView)
    
    rightView.didTapAmount = { [weak self] in
      self?.didTapAmount?()
    }
    
    highlightView.snp.makeConstraints { make in
      make.edges.equalTo(contentView)
    }
    
    informationView.snp.makeConstraints { make in
      make.top.left.bottom.equalTo(contentView)
      make.right.equalTo(rightView.snp.left)
    }
    
    rightView.snp.makeConstraints { make in
      make.top.right.bottom.equalTo(contentView)
    }
  }
}
