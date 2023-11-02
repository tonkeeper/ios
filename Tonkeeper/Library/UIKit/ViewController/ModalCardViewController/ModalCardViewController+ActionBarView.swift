//
//  ModalCardViewController+ActionBarView.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 20.10.2023.
//

import UIKit
import TKUIKit

extension ModalCardViewController {
  final class ActionBar: UIView, ConfigurableView {
    private weak var viewController: UIViewController?
    private let contentStackView: UIStackView = {
      let stackView = UIStackView()
      stackView.axis = .vertical
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
    
    // MARK: - Init
    
    init(viewController: UIViewController) {
      self.viewController = viewController
      super.init(frame: .zero)
      setup()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - ConfigurableView
    
    func configure(model: Configuration.ActionBar) {
      guard let viewController = viewController else { return }
      let views = ModalCardViewBuilder.buildViews(
        items: model.items,
        viewController: viewController) { [weak self] state in
          switch state {
          case .none:
            self?.hideLoader()
            self?.hideResult()
            self?.showContent()
          case .activity:
            self?.hideResult()
            self?.hideContent()
            self?.showLoader()
          case .result(let isSuccess):
            self?.hideLoader()
            self?.hideContent()
            self?.showResult(isSuccess: isSuccess)
          }
        }
      views.forEach { view in
        contentStackView.addArrangedSubview(view)
      }
    }
  }
}

private extension ModalCardViewController.ActionBar {
  func setup() {
    addSubview(backgroundView)
    addSubview(contentStackView)
    addSubview(loaderView)
    addSubview(resultView)
    
    loaderView.isHidden = true
    resultView.isHidden = true
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    loaderView.translatesAutoresizingMaskIntoConstraints = false
    resultView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      backgroundView.topAnchor.constraint(equalTo: topAnchor),
      backgroundView.leftAnchor.constraint(equalTo: leftAnchor),
      backgroundView.rightAnchor.constraint(equalTo: rightAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: topAnchor,
                                            constant: ContentInsets.sideSpace),
      contentStackView.leftAnchor.constraint(equalTo: leftAnchor,
                                             constant: ContentInsets.sideSpace),
      contentStackView.rightAnchor.constraint(equalTo: rightAnchor,
                                              constant: -ContentInsets.sideSpace),
      contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      loaderView.topAnchor.constraint(equalTo: contentStackView.topAnchor),
      loaderView.leftAnchor.constraint(equalTo: contentStackView.leftAnchor),
      loaderView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),
      loaderView.rightAnchor.constraint(equalTo: contentStackView.rightAnchor),

      resultView.topAnchor.constraint(equalTo: contentStackView.topAnchor),
      resultView.leftAnchor.constraint(equalTo: contentStackView.leftAnchor),
      resultView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),
      resultView.rightAnchor.constraint(equalTo: contentStackView.rightAnchor)
    ])
  }
  
  func showContent() {
    contentStackView.isHidden = false
  }
  
  func hideContent() {
    contentStackView.isHidden = true
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
}
