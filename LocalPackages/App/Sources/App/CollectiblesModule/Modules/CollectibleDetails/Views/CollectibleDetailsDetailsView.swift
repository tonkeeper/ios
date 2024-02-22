import UIKit
import TKUIKit

final class CollectibleDetailsDetailsView: UIView, ConfigurableView {
  
  var didTapOpenInExplorer: (() -> Void)?
  
  let titleView = TKListTitleView()
  let viewInExplorerButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitleColor(.Text.accent, for: .normal)
    button.titleLabel?.font = TKTextStyle.label1.font
    return button
  }()
  let listView = TKModalCardListView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let titleViewModel: TKListTitleView.Model
    let buttonTitle: String?
    let listViewModel: TKModalCardListView.Model
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.titleViewModel)
    viewInExplorerButton.setTitle(model.buttonTitle, for: .normal)
    listView.configure(model: model.listViewModel)
  }
}

private extension CollectibleDetailsDetailsView {
  func setup() {
    addSubview(titleView)
    addSubview(viewInExplorerButton)
    addSubview(listView)
    
    viewInExplorerButton.setContentHuggingPriority(.required, for: .horizontal)
    viewInExplorerButton.addTarget(
      self,
      action: #selector(didTapOpenInExplorerButton),
      for: .touchUpInside
    )
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleView.translatesAutoresizingMaskIntoConstraints = false
    viewInExplorerButton.translatesAutoresizingMaskIntoConstraints = false
    listView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      titleView.topAnchor.constraint(equalTo: topAnchor),
      titleView.leftAnchor.constraint(equalTo: leftAnchor),
      
      viewInExplorerButton.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
      viewInExplorerButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -16),
      viewInExplorerButton.leftAnchor.constraint(equalTo: titleView.rightAnchor),
      
      listView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
      listView.leftAnchor.constraint(equalTo: leftAnchor),
      listView.rightAnchor.constraint(equalTo: rightAnchor),
      listView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
  
  @objc
  func didTapOpenInExplorerButton() {
    didTapOpenInExplorer?()
  }
}
