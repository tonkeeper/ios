import UIKit

final class TKPopupMenuView: UIView {
  
  var didSelectItem: (() -> Void)?
  
  var items: [TKPopupMenuItemView.Model] = [] {
    didSet {
      didSetItems()
    }
  }
  
  private var itemViews = [TKPopupMenuItemView]()
  
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
  
  func selectItem(index: Int) {
    guard items.count > index else { return }
    itemViews[index].isSelected = true
  }
  
  private func setup() {
    layer.cornerRadius = 16
    layer.masksToBounds = true
    
    addSubview(stackView)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
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

