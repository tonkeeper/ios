//
//  ModalContentViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import UIKit

final class ModalContentViewController: UIViewController, ScrollableModalCardContainerContent {
  
  var isRespectSafeArea: Bool = true {
    didSet {
      actionBarView.isRespectSafeArea = isRespectSafeArea
      didUpdateRespectSafeArea()
    }
  }
  
  let scrollView: UIScrollView = {
    return NotDelayScrollView()
  }()
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  private let contentView = UIView()
  private let headerView = ModalContentHeaderView()
  private let listView = ModalContentListView()
  private lazy var actionBarView = ModalContentActionBarView(parentViewController: self)
  
  private let listTopSpacingView = SpacingView(verticalSpacing: .constant(.listTopSpace))
  private let listBottomSpacingView = SpacingView(verticalSpacing: .constant(.listItemsBottomSpace))
  
  private var actionBarBottomConstraint: NSLayoutConstraint?
  
  private var contentSizeObserveToken: NSKeyValueObservation?
  
  private var _configuration = Configuration(header: nil, listItems: [], actionBar: nil)
  
  var configuration: Configuration {
    get {
      _configuration
    }
    set {
      _configuration = newValue
      configure()
    }
  }
  
  var headerModel: Configuration.Header? {
    get {
      _configuration.header
    }
    set {
      _configuration.header = newValue
      configureHeader(model: _configuration.header)
    }
  }
  
  var listItemsModel: [Configuration.ListItem] {
    get {
      _configuration.listItems
    }
    set {
      _configuration.listItems = newValue
      configureListItems(model: _configuration.listItems)
    }
  }
  
  var actionBarModel: Configuration.ActionBar? {
    get {
      _configuration.actionBar
    }
    set {
      _configuration.actionBar = newValue
      configureActionBar(model: _configuration.actionBar)
    }
  }
  
  init() {
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
    updateActionBarBottomConstraint()
  }
  
  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    updateActionBarBottomConstraint()
  }
  
  // MARK: - ScrollableModalCardContainerContent
  
  var height: CGFloat {
    let height = scrollView.contentSize.height + scrollView.contentInset.top + scrollView.contentInset.bottom
    return height
  }
  
  var didUpdateHeight: (() -> Void)?
}

// MARK: - Private

private extension ModalContentViewController {
  func setup() {
    view.backgroundColor = .Background.page
    
    view.addSubview(scrollView)
    view.addSubview(actionBarView)
    scrollView.addSubview(contentView)
    contentView.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(headerView)
    contentStackView.addArrangedSubview(listTopSpacingView)
    contentStackView.addArrangedSubview(listView)
    contentStackView.addArrangedSubview(listBottomSpacingView)
    
    setupConstraints()
    configure()
    
    contentSizeObserveToken = scrollView
      .observe(\.contentSize, changeHandler: { [weak self] _, _ in
        guard let self else { return }
        self.didUpdateHeight?()
      })
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    actionBarView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    
    actionBarBottomConstraint = actionBarView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    actionBarBottomConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
      
      contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: ContentInsets.sideSpace),
      contentStackView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -ContentInsets.sideSpace),
      contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      
      actionBarView.leftAnchor.constraint(equalTo: view.leftAnchor),
      actionBarView.rightAnchor.constraint(equalTo: view.rightAnchor)
    ])
  }
  
  func configure() {
    guard isViewLoaded else { return }
    configureHeader(model: configuration.header)
    configureListItems(model: configuration.listItems)
    configureActionBar(model: configuration.actionBar)
  }
  
  func configureHeader(model: Configuration.Header?) {
    guard isViewLoaded else { return }
    if let model = model {
      headerView.configure(model: model)
      headerView.isHidden = false
    } else {
      headerView.isHidden = true
    }
  }
  
  func configureListItems(model: [Configuration.ListItem]) {
    guard isViewLoaded else { return }
    if model.isEmpty {
      listView.isHidden = true
      listTopSpacingView.isHidden = true
      listBottomSpacingView.isHidden = true
    } else {
      listTopSpacingView.isHidden = false
      listBottomSpacingView.isHidden = false
      listView.configure(model: model)
      listView.isHidden = false
    }
  }
  
  func configureActionBar(model: Configuration.ActionBar?) {
    guard isViewLoaded else { return }
    if let model = model {
      actionBarView.isHidden = false
      actionBarView.configure(model: model)
    } else {
      actionBarView.isHidden = true
    }
  }
  
  func updateActionBarBottomConstraint() {
    let scrollViewBottomContentInset = actionBarView.bounds.height
    scrollView.contentInset.bottom = scrollViewBottomContentInset
    
    actionBarBottomConstraint?.constant = 0
  }
  
  func didUpdateRespectSafeArea() {
    updateActionBarBottomConstraint()
  }
}

private extension CGFloat {
  static let listTopSpace: CGFloat = 32
  static let buttonVerticalSpace: CGFloat = 16
  static let listItemsBottomSpace: CGFloat = 16
}
