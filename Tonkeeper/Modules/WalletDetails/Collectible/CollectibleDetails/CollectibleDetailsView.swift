//
//  CollectibleDetailsCollectibleDetailsView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 21/08/2023.
//

import UIKit

final class CollectibleDetailsView: UIView {
  
  private let scrollView: UIScrollView = {
    return NotDelayScrollView()
  }()
  private let scrollContent = UIView()
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  let collectionDescriptionView = CollectibleDetailsCollectionDescriptionView()
  let detailsView = CollectibleDetailsDetailsView()
  

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Private

private extension CollectibleDetailsView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(scrollView)
    scrollView.addSubview(scrollContent)
    scrollContent.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(collectionDescriptionView)
    contentStackView.addArrangedSubview(detailsView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    scrollContent.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      scrollContent.topAnchor.constraint(equalTo: scrollView.topAnchor),
      scrollContent.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      scrollContent.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      scrollContent.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      scrollContent.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: scrollContent.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollContent.leftAnchor, constant: ContentInsets.sideSpace),
      contentStackView.rightAnchor.constraint(equalTo: scrollContent.rightAnchor, constant: -ContentInsets.sideSpace),
      contentStackView.bottomAnchor.constraint(equalTo: scrollContent.bottomAnchor)
    ])
  }
}
