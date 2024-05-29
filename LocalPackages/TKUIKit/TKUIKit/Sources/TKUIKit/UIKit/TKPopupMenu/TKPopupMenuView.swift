import UIKit

final class TKPopupMenuView: UIView {
  
  var didSelectItem: (() -> Void)?
  
  var items: [TKPopupMenuItemView.Model] = [] {
    didSet {
      didSetItems()
    }
  }
  
  private var itemViews = [TKPopupMenuItemView]()
  private let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.contentTint
    view.layer.cornerRadius = 16
    view.layer.masksToBounds = true
    return view
  }()
  private let shadowViewOne: UIView = {
    let view = UIView()
    view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
    view.layer.shadowRadius = 64
    view.layer.shadowOffset = CGSize(width: 0, height: 16)
    view.layer.shadowOpacity = 1
    return view
  }()
  private let shadowViewTwo: UIView = {
    let view = UIView()
    view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
    view.layer.shadowRadius = 16
    view.layer.shadowOffset = CGSize(width: 0, height: 4)
    view.layer.shadowOpacity = 1
    return view
  }()
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    shadowViewOne.frame = bounds
    shadowViewOne.layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    shadowViewTwo.frame = bounds
    shadowViewTwo.layer.shadowPath = UIBezierPath(rect: bounds).cgPath
  }
  
  func selectItem(index: Int) {
    guard items.count > index else { return }
    itemViews[index].isSelected = true
  }
  
  private func setup() {
    addSubview(shadowViewOne)
    addSubview(shadowViewTwo)
    addSubview(backgroundView)
    backgroundView.addSubview(stackView)
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(backgroundView)
    }
  }
  
  private func didSetItems() {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    itemViews = []
    items.enumerated().forEach { index, item in
      let itemView = TKPopupMenuItemView()
      itemView.configure(model: item)
      itemView.didTap = { [weak self] in
        self?.itemViews.forEach { $0.isSelected = $0 == itemView }
        self?.items[index].selectionHandler?()
        self?.didSelectItem?()
      }
      stackView.addArrangedSubview(itemView)
      itemViews.append(itemView)
    }
  }
}

