//
//  ModalContentViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import UIKit

final class ModalContentViewController: UIViewController {
  private let scrollView = UIScrollView()
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  private let headerView = ModalContentHeaderView()
  private let listView = ModalContentListView()
  private let actionBarView = ModalContentActionBarView()
  
  private var actionBarBottomConstraint: NSLayoutConstraint?
  
  private var configuration: Configuration {
    didSet { configure() }
  }
  
  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    scrollView.contentInset.bottom = actionBarView.frame.height + .buttonVerticalSpace * 2
  }
  
  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    updateActionBarBottomConstraint()
  }
}

// MARK: - Private

private extension ModalContentViewController {
  func setup() {
    view.backgroundColor = .Background.page
    
    view.addSubview(scrollView)
    view.addSubview(actionBarView)
    scrollView.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(headerView)
    contentStackView.addArrangedSubview(listView)
    
    contentStackView.setCustomSpacing(.headerBottomSpace, after: headerView)
    
    setupConstraints()
    configure()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    actionBarView.translatesAutoresizingMaskIntoConstraints = false
    
    actionBarBottomConstraint = actionBarView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    actionBarBottomConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      
      actionBarView.leftAnchor.constraint(equalTo: view.leftAnchor),
      actionBarView.rightAnchor.constraint(equalTo: view.rightAnchor)
    ])
  }
  
  func configure() {
    headerView.configure(model: configuration.header)
    listView.configure(model: configuration.listItems)
    actionBarView.configure(model: configuration.actionBar)
  }

  func updateActionBarBottomConstraint() {
    scrollView.contentInset.bottom = view.safeAreaInsets.bottom + .buttonVerticalSpace
    actionBarBottomConstraint?.constant = 0
  }
}

private extension CGFloat {
  static let headerBottomSpace: CGFloat = 32
  static let buttonVerticalSpace: CGFloat = 16
}
