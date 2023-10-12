//
//  ScrollContainerWithTitleAndDescription.swift
//  Tonkeeper
//
//  Created by Grigory on 11.10.23..
//

import UIKit

final class ScrollContainerWithTitleAndDescription: UIView, ConfigurableView {
  
  let scrollView: UIScrollView = {
    let scrollView = NotDelayScrollView()
    scrollView.showsVerticalScrollIndicator = false
    return scrollView
  }()
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  let footerStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 2
    return label
  }()
  let descriptionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  var scrollContentInset: UIEdgeInsets {
    get { scrollView.contentInset }
    set { scrollView.contentInset = newValue }
  }
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let title: NSAttributedString
    let description: NSAttributedString
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    descriptionLabel.attributedText = model.description
  }
  
  // MARK: - Content
  
  func addContentSubview(_ subview: UIView, 
                         spacingAfter: CGFloat? = nil) {
    contentStackView.addArrangedSubview(subview)
    if let spacingAfter = spacingAfter {
      contentStackView.setCustomSpacing(spacingAfter, after: subview)
    }
  }
  
  func addFooterSubview(_ subview: UIView,
                        spacingAfter: CGFloat? = nil) {
    footerStackView.addArrangedSubview(subview)
    if let spacingAfter = spacingAfter {
      footerStackView.setCustomSpacing(spacingAfter, after: subview)
    }
  }
  
  func scrollToView(_ view: UIView,
                    animationDuration: TimeInterval) {
    let viewFrame = scrollView.convert(view.frame, from: view.superview)
    let scrollViewMaxOrigin = scrollView.contentSize.height
    - scrollView.frame.height
    + scrollView.contentInset.bottom
    let originY = min(viewFrame.origin.y - 64, scrollViewMaxOrigin)
    UIView.animate(withDuration: animationDuration) {
      self.scrollView.contentOffset = .init(x: 0, y: originY)
    }
  }
}

private extension ScrollContainerWithTitleAndDescription {
  func setup() {
    backgroundColor = .Background.page

    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    scrollView.addSubview(footerStackView)

    contentStackView.addArrangedSubview(titleLabel)
    contentStackView.addArrangedSubview(descriptionLabel)
    contentStackView.setCustomSpacing(.titleBottomSpace, after: titleLabel)
    contentStackView.setCustomSpacing(.descriptionBottomSpace, after: descriptionLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    footerStackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrollView.widthAnchor.constraint(equalTo: widthAnchor),

      contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor, constant: .contentSideSpace),
      contentStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor, constant: -.contentSideSpace).withPriority(.defaultHigh),
      
      footerStackView.topAnchor.constraint(equalTo: contentStackView.bottomAnchor),
      footerStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      footerStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      footerStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      footerStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
    ])
  }
}

private extension CGFloat {
  static let contentSideSpace: CGFloat = 32
  static let titleBottomSpace: CGFloat = 4
  static let descriptionBottomSpace: CGFloat = 32
}

