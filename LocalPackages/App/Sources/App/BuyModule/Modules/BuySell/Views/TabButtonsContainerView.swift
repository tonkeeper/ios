import UIKit
import TKUIKit

protocol TabButtonContainerDelegate: AnyObject {
  func itemDidSelect(withId id: TabButtonItem.ID)
}

// MARK: - TabButtonsContainerView

final class TabButtonsContainerView: UIView, ConfigurableView {
  
  var itemDidSelect: ((TabButtonItem.ID) -> Void)?
  
  private var selectedId: TabButtonItem.ID = 0
  private var items: [TabButtonItem] = []
  
  private let itemsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  private let line: UIView = {
    let view = UIView()
    view.backgroundColor = .Accent.blue
    return view
  }()
  
  init() {
    super.init(frame: CGRect(x: 0, y: 0, width: 262, height: 53))
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let width = items.reduce(0) { $0 + $1.sizeThatFits(bounds.size).width }
    return CGSize(width: width, height: .tabButtonItemHeight)
  }
  
  struct Model {
    let tabButtons: [TabButtonItem.Model]
  }
  
  func configure(model: Model) {
    items = model.tabButtons.enumerated().map { mapTabButton($1, withId: $0) }
    
    if let firstItem = items.first {
      firstItem.isSelected = true
      let lineWidth = firstItem.sizeThatFits(bounds.size).width - .lineHorizontalPadding * 2
      line.frame = CGRect(x: .lineHorizontalPadding, y: .titleViewHeight, width: lineWidth, height: 3)
      line.layer.cornerRadius = line.bounds.height / 2
    }
    
    itemsStackView.arrangedSubviews.forEach { view in
      itemsStackView.removeArrangedSubview(view)
      view.removeFromSuperview()
    }
    items.forEach { itemsStackView.addArrangedSubview($0) }
  }
}

private extension TabButtonsContainerView {
  func setup() {
    addSubview(itemsStackView)
    addSubview(line)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    itemsStackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
  
  func mapTabButton(_ tabButton: TabButtonItem.Model, withId id: TabButtonItem.ID) -> TabButtonItem {
    let tabButtonItem = TabButtonItem(id: id)
    tabButtonItem.configure(model: tabButton)
    tabButtonItem.delegate = self
    return tabButtonItem
  }
}

extension TabButtonsContainerView: TabButtonContainerDelegate {
  func itemDidSelect(withId id: TabButtonItem.ID) {
    guard id != selectedId else { return }
    
    if let selectedItem = item(withId: id) {
      let selectedFrame = convert(selectedItem.frame, to: self)
      
      UIView.animate(
        withDuration: 0.2,
        delay: 0,
        usingSpringWithDamping: 0.8,
        initialSpringVelocity: 3,
        options: [.beginFromCurrentState, .curveEaseOut]
      ) {
        self.line.frame.origin.x = selectedFrame.origin.x + .lineHorizontalPadding
        self.line.frame.size.width = selectedFrame.width - .lineHorizontalPadding * 2
      }
    }
    
    let itemToDeselect = item(withId: selectedId)
    itemToDeselect?.deselectItem()
    selectedId = id
    itemDidSelect?(id)
  }
  
  private func item(withId id: TabButtonItem.ID) -> TabButtonItem? {
    return items.first(where: { $0.id == id })
  }
}

// MARK: - TabButtonItem

final class TabButtonItem: UIControl, ConfigurableView, Identifiable {
  
  enum ItemState {
    case normal
    case selected
    case highlighted
  }
  
  private var itemState: ItemState = .normal {
    didSet {
      guard itemState != oldValue else { return }
      updateTitleTextColor(itemState: itemState, oldItemState: oldValue)
    }
  }
  
  override var isSelected: Bool {
    didSet {
      guard isSelected != oldValue else { return }
      updateItemState()
    }
  }
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      updateItemState()
    }
  }
  
  weak var delegate: TabButtonContainerDelegate?
  
  override var intrinsicContentSize: CGSize { sizeThatFits(bounds.size) }
  
  let titleLabel = UILabel()
  let titleView = UIView()
  
  let id: Int
  
  init(id: Int) {
    self.id = id
    super.init(frame: .zero)
    self.setup()
    self.setupActions()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    var width = titleLabel.sizeThatFits(size).width
    width += .titleLabelHorizontalPadding * 2 + .titleViewHorizontalPadding * 2
    return CGSize(width: width, height: .tabButtonItemHeight)
  }
  
  struct Model {
    let title: String
    let selectionClosure: (() -> Void)?
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(.label1, color: .Text.secondary)
    
    addAction(UIAction(handler: { _ in
      model.selectionClosure?()
    }), for: .touchUpInside)
  }
  
  func selectItem() {
    isSelected = true
    delegate?.itemDidSelect(withId: id)
  }
  
  func deselectItem() {
    isSelected = false
  }
}

private extension TabButtonItem {
  func setup() {
    addSubview(titleView)
    titleView.addSubview(titleLabel)
    
    titleView.isUserInteractionEnabled = false
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleViewHeight)
      make.top.equalTo(self)
      make.left.right.equalTo(self).inset(CGFloat.titleViewHorizontalPadding)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleLabelHeight)
      make.top.equalTo(titleView).offset(CGFloat.titleLabelTopPadding)
      make.left.right.equalTo(titleView).inset(CGFloat.titleLabelHorizontalPadding)
    }
  }
  
  func setupActions() {
    addAction(UIAction(handler: { [weak self] _ in
      self?.selectItem()
    }), for: .touchUpInside)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.isHighlighted = true
    }), for: .touchDragInside)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.isHighlighted = false
    }), for: .touchDragOutside)
  }
}

private extension TabButtonItem {
  func updateItemState() {
    switch (isHighlighted, isSelected) {
    case (_, true):
      itemState = .selected
    case (true, false):
      itemState = .highlighted
    case (false, false):
      itemState = .normal
    }
  }
  
  func updateTitleTextColor(itemState: ItemState, oldItemState: ItemState) {
    if itemState == .highlighted {
      titleLabel.textColor = .Text.secondary.withAlphaComponent(0.9)
    } else if itemState == .normal, oldItemState == .highlighted {
      titleLabel.textColor = .Text.secondary
    } else if itemState != oldItemState {
      UIView.transition(
        with: titleLabel,
        duration: 0.1,
        options: [.transitionCrossDissolve, .beginFromCurrentState, .curveEaseInOut]
      ) {
        self.titleLabel.textColor = itemState == .selected ? .Text.primary : .Text.secondary
      }
    }
  }
}

private extension CGFloat {
  static let tabButtonItemHeight: CGFloat = 53
  static let titleLabelHeight: CGFloat = 24
  static let titleLabelTopPadding: CGFloat = 4
  static let titleLabelHorizontalPadding: CGFloat = 16
  static let titleViewHeight: CGFloat = 34
  static let titleViewHorizontalPadding: CGFloat = 5.5
  static let lineHorizontalPadding: CGFloat = 8
}
