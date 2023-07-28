//
//  ModalContentActionBarView.swift
//  Tonkeeper
//
//  Created by Grigory on 3.6.23..
//

import UIKit

final class ModalContentActionBarView: UIView, ConfigurableView {
  
  var isRespectSafeArea: Bool = true {
    didSet {
      updateStackViewBottomConstraint()
    }
  }
  
  private let itemsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = .contentSpacing
    return stackView
  }()
  
  private let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    return view
  }()
  
  private let loaderView: LoaderView = {
    let view = LoaderView(size: .medium)
    view.color = .Icon.secondary
    return view
  }()
  
  private let resultView = ResultView(state: .success)
  
  private var stackViewBottomConstraint: NSLayoutConstraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    updateStackViewBottomConstraint()
  }
  
  func configure(model: ModalContentViewController.Configuration.ActionBar) {
    itemsStackView.subviews.forEach { $0.removeFromSuperview() }
    
    model.items.forEach { item in
      switch item {
      case let .buttons(buttonModels):
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = .contentSpacing
        buttonModels.forEach { buttonModel in
          let button = TKButton(configuration: buttonModel.configuration)
          let buttonActivityContainer = ActivityViewContainer(view: button)
          button.addAction(.init(handler: { [weak self] in
            let completionClosure: (Bool) -> Void = { [weak self] isSuccess in
              self?.hideLoader()
              self?.hideActions()
              self?.showResult(isSuccess: isSuccess)
              DispatchQueue.main.asyncAfter(deadline: .now() + .completionDelay) {
                buttonModel.completion?(isSuccess)
                self?.showActions()
                self?.hideResult()
              }
            }
            buttonModel.tapAction?(completionClosure)
            if buttonModel.showActivityOnTap?() == true {
              self?.hideActions()
              self?.showLoader()
            }
          }), for: .touchUpInside)
          if buttonModel.showActivity?() == true {
            buttonActivityContainer.showActivity()
          }
          button.titleLabel.text = buttonModel.title
          stackView.addArrangedSubview(buttonActivityContainer)
        }
        itemsStackView.addArrangedSubview(stackView)
      }
    }
  }
}

private extension ModalContentActionBarView {
  func setup() {
    addSubview(backgroundView)
    addSubview(itemsStackView)
    addSubview(loaderView)
    addSubview(resultView)
    
    loaderView.isHidden = true
    resultView.isHidden = true
    
    setupConstraints()
  }
  
  func setupConstraints() {
    itemsStackView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    loaderView.translatesAutoresizingMaskIntoConstraints = false
    resultView.translatesAutoresizingMaskIntoConstraints = false
    
    stackViewBottomConstraint = itemsStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
    stackViewBottomConstraint?.isActive = true
    NSLayoutConstraint.activate([
      backgroundView.topAnchor.constraint(equalTo: topAnchor),
      backgroundView.leftAnchor.constraint(equalTo: leftAnchor),
      backgroundView.rightAnchor.constraint(equalTo: rightAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      itemsStackView.topAnchor.constraint(equalTo: topAnchor, constant: .contentSpacing),
      itemsStackView.leftAnchor.constraint(equalTo: leftAnchor, constant: .contentSpacing),
      itemsStackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.contentSpacing),
      
      loaderView.topAnchor.constraint(equalTo: itemsStackView.topAnchor),
      loaderView.leftAnchor.constraint(equalTo: itemsStackView.leftAnchor),
      loaderView.bottomAnchor.constraint(equalTo: itemsStackView.bottomAnchor),
      loaderView.rightAnchor.constraint(equalTo: itemsStackView.rightAnchor),

      resultView.topAnchor.constraint(equalTo: itemsStackView.topAnchor),
      resultView.leftAnchor.constraint(equalTo: itemsStackView.leftAnchor),
      resultView.bottomAnchor.constraint(equalTo: itemsStackView.bottomAnchor),
      resultView.rightAnchor.constraint(equalTo: itemsStackView.rightAnchor)
    ])
  }

  func hideActions() {
    itemsStackView.isHidden = true
  }
  
  func showActions() {
    itemsStackView.isHidden = false
  }
  
  func showLoader() {
    loaderView.startAnimation()
    loaderView.isHidden = false
  }
  
  func hideLoader() {
    loaderView.stopAnimation()
    loaderView.isHidden = true
  }
  
  func showResult(isSuccess: Bool) {
    resultView.isHidden = false
    resultView.state = isSuccess ? .success : .failure
  }
  
  func hideResult() {
    resultView.isHidden = true
  }
  
  func updateStackViewBottomConstraint() {
    let additionalBottomSpace = isRespectSafeArea ? safeAreaInsets.bottom : 0
    stackViewBottomConstraint?.constant = -(additionalBottomSpace + .contentSpacing)
  }
}

private extension CGFloat {
  static let itemsSpacing: CGFloat = 16
  static let contentSpacing: CGFloat = 16
}

private extension TimeInterval {
  static let completionDelay: TimeInterval = 1
}
