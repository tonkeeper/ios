//
//  SettingsRecoveryPhraseView.swift
//  Tonkeeper
//
//  Created by Grigory on 11.10.23..
//

import UIKit

final class SettingsRecoveryPhraseView: UIView, ConfigurableView {
  
  let scrollContainer = ScrollContainerWithTitleAndDescription()
  let phraseListView = RecoveryPhraseListView()
  let button = TKButton(configuration: .secondaryLarge)
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    scrollContainer.frame = bounds
    scrollContainer.scrollContentInset.bottom = button.bounds.height + 48
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let scrollContainerModel: ScrollContainerWithTitleAndDescription.Model
    let phraseListViewModel: RecoveryPhraseListView.Model
    let buttonConfiguration: TKButton.Configuration
    let buttonModel: TKButton.Model
    let buttonAction: () -> Void
  }
  
  func configure(model: Model) {
    scrollContainer.configure(model: model.scrollContainerModel)
    phraseListView.configure(model: model.phraseListViewModel)
    
    button.configuration = model.buttonConfiguration
    button.configure(model: model.buttonModel)
    button.addAction(UIControlClosure.UIAction(handler: {
      model.buttonAction()
    }), for: .touchUpInside)
  }
}

// MARK: - Private

private extension SettingsRecoveryPhraseView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(scrollContainer)
    addSubview(button)
    
    scrollContainer.addContentSubview(phraseListView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -32),
      button.leftAnchor.constraint(equalTo: leftAnchor, constant: 32),
      button.rightAnchor.constraint(equalTo: rightAnchor, constant: -32)
    ])
  }
}

