//
//  CollectibleDetailsDetailsView.swift
//  Tonkeeper
//
//  Created by Grigory on 22.8.23..
//

import UIKit

final class CollectibleDetailsDetailsView: UIView, ConfigurableView {
  
  let titleView = ListTitleView()
  let viewInExplorerButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitleColor(.Text.accent, for: .normal)
    button.titleLabel?.applyTextStyleFont(.label1)
    return button
  }()
  let listView = ModalContentListView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let titleViewModel: ListTitleView.Model
    let buttonTitle: String?
    let listViewModel: ModalContentListView.Model
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
      viewInExplorerButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      viewInExplorerButton.leftAnchor.constraint(equalTo: titleView.rightAnchor),
      
      listView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
      listView.leftAnchor.constraint(equalTo: leftAnchor),
      listView.rightAnchor.constraint(equalTo: rightAnchor),
      listView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}
