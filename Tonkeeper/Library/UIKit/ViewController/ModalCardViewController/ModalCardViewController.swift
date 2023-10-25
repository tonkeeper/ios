//
//  ModalCardViewController.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 20.10.2023.
//

import UIKit

final class ModalCardViewController: UIViewController, ScrollableModalCardContainerContent {
  let scrollView: UIScrollView = {
    NotDelayScrollView()
  }()
  private let scrollViewContentView = UIView()
  private let contentStackView = UIStackView()
  
  private lazy var headerView = ModalCardViewController.HeaderView(viewController: self)
  private lazy var actionBarView = ModalCardViewController.ActionBar(viewController: self)
  
  private var actionBarBottomConstraint: NSLayoutConstraint?
  
  private var _configuration = ModalCardViewController.Configuration(header: nil)
  var configuration: ModalCardViewController.Configuration {
    get { _configuration }
    set { _configuration = newValue; configure() }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateActionBarBottomConstraint()
  }
  
  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    updateActionBarBottomConstraint()
  }
  
  // MARK: - ScrollableModalCardContainerContent
  
  var height: CGFloat {
    let height = scrollView.contentSize.height
    + scrollView.contentInset.top
    + scrollView.contentInset.bottom
    return height
  }
  
  var didUpdateHeight: (() -> Void)?
}

private extension ModalCardViewController {
  func configure() {
    guard isViewLoaded else { return }
    configureHeader()
    configureActionBar()
  }
  
  func configureHeader() {
    guard isViewLoaded else { return }
    guard let model = configuration.header else {
      headerView.isHidden = true
      return
    }
    headerView.isHidden = false
    headerView.configure(model: model)
  }
  
  func configureActionBar() {
    guard isViewLoaded else { return }
    guard let model = configuration.actionBar else {
      actionBarView.isHidden = true
      return
    }
    actionBarView.isHidden = false
    actionBarView.configure(model: model)
  }
  
  func setup() {
    view.backgroundColor = .Background.page
    
    scrollView.contentInsetAdjustmentBehavior = .never
    
    view.addSubview(scrollView)
    view.addSubview(actionBarView)
    scrollView.addSubview(scrollViewContentView)
    scrollViewContentView.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(headerView)
    
    setupConstraints()
    
    configure()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollViewContentView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    actionBarView.translatesAutoresizingMaskIntoConstraints = false
    
    actionBarBottomConstraint = actionBarView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    actionBarBottomConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
      
      scrollViewContentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      scrollViewContentView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      scrollViewContentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      scrollViewContentView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      scrollViewContentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: scrollViewContentView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollViewContentView.leftAnchor,
                                             constant: ContentInsets.sideSpace),
      contentStackView.rightAnchor.constraint(equalTo: scrollViewContentView.rightAnchor,
                                              constant: -ContentInsets.sideSpace),
      contentStackView.bottomAnchor.constraint(equalTo: scrollViewContentView.bottomAnchor),
      
      actionBarView.leftAnchor.constraint(equalTo: view.leftAnchor),
      actionBarView.rightAnchor.constraint(equalTo: view.rightAnchor)
    ])
  }
  
  func updateActionBarBottomConstraint() {
    let scrollViewBottomContentInset = actionBarView.bounds.height
    scrollView.contentInset.bottom = scrollViewBottomContentInset
    actionBarBottomConstraint?.constant = 0
  }
}
