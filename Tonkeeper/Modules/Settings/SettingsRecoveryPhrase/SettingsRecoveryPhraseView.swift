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
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let scrollContainerModel: ScrollContainerWithTitleAndDescription.Model
    let phraseListViewModel: RecoveryPhraseListView.Model
  }
  
  func configure(model: Model) {
    scrollContainer.configure(model: model.scrollContainerModel)
    phraseListView.configure(model: model.phraseListViewModel)
  }
}

// MARK: - Private

private extension SettingsRecoveryPhraseView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(scrollContainer)
    
    scrollContainer.addContentSubview(phraseListView)
  }
}

