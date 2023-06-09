//
//  PageSegmentControl.swift
//  Tonkeeper
//
//  Created by Grigory on 30.5.23..
//

import UIKit

final class PageSegmentControl: UIControl, ConfigurableView {
  struct Model {
    let items: [PageSegmentControlTab.Model]
  }
  
  var selectedIndex: Int {
    get { _selectedIndex }
    set {
      _selectedIndex = newValue
      selectTabAt(index: newValue, animated: true)
    }
  }
  
  var didSelectTab: ((Int) -> Void)?
  
  private var _selectedIndex = 0
  
  private var tabs = [PageSegmentControlTab]()
  private let scrollView = UIScrollView()
  private let tabsContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  private let indicatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Accent.blue
    view.layer.cornerRadius = .indicatorViewHeight/2
    view.layer.masksToBounds = true
    return view
  }()
  
  private var contentSizeObserveToken: NSKeyValueObservation?
  
  private var scrollViewCenterXConstraint: NSLayoutConstraint?
  private var scrollViewLeftConstraint: NSLayoutConstraint?
  private var scrollViewRightConstraint: NSLayoutConstraint?
  private var scrollViewWidthConstraint: NSLayoutConstraint?
  
  private var indicatorViewCenterXConstraint: NSLayoutConstraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    .init(width: UIView.noIntrinsicMetric,
          height: .height)
  }
  
  func configure(model: Model) {
    tabsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
    tabs = model.items.enumerated().map { index, model in
      let tab = PageSegmentControlTab()
      tab.configure(model: model)
      tab.addAction(.init(handler: { [weak self] in
        self?.selectTabAt(index: index, animated: true)
        self?.didSelectTab?(index)
      }), for: .touchUpInside)
      return tab
    }
    tabs.forEach { tabsContainer.addArrangedSubview($0) }
    guard !tabs.isEmpty else { return }
    selectTabAt(index: 0, animated: false)
  }
  
  func updateIndicator(fromPage: Int, toPage: Int, progress: CGFloat) {
    let fromFrame = scrollView.convert(tabs[fromPage].frame, from: tabsContainer)
    let toFrame = scrollView.convert(tabs[toPage].frame, from: tabsContainer)
    
    let fromX = fromFrame.midX - .indicatorViewWidth/2
    let toX = toFrame.midX - .indicatorViewWidth/2
    let resultX = fromX + (toX - fromX) * progress
    indicatorViewCenterXConstraint?.constant = resultX
  }
}

private extension PageSegmentControl {
  func setup() {
    contentSizeObserveToken = scrollView.observe(\.contentOffset, changeHandler: { [weak self] scrollView, _ in
      guard let self = self else { return }
      let isContentSmaller = scrollView.contentSize.width < self.bounds.width
      self.scrollViewLeftConstraint?.isActive = !isContentSmaller
      self.scrollViewRightConstraint?.isActive = !isContentSmaller
      self.scrollViewCenterXConstraint?.isActive = isContentSmaller
      self.scrollViewWidthConstraint?.isActive = isContentSmaller
    })
    
    addSubview(scrollView)
    scrollView.addSubview(tabsContainer)
    scrollView.addSubview(indicatorView)
    
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    tabsContainer.translatesAutoresizingMaskIntoConstraints = false
    indicatorView.translatesAutoresizingMaskIntoConstraints = false
    
    scrollViewCenterXConstraint = scrollView.centerXAnchor.constraint(equalTo: centerXAnchor)
    scrollViewLeftConstraint = scrollView.leftAnchor.constraint(equalTo: leftAnchor)
    scrollViewRightConstraint = scrollView.rightAnchor.constraint(equalTo: rightAnchor)
    scrollViewWidthConstraint = scrollView.widthAnchor.constraint(equalTo: tabsContainer.widthAnchor)
    
    indicatorViewCenterXConstraint = indicatorView.leftAnchor.constraint(equalTo: scrollView.leftAnchor)
    indicatorViewCenterXConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollViewLeftConstraint!,
      scrollViewRightConstraint!,
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
    
      tabsContainer.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      tabsContainer.rightAnchor.constraint(equalTo: scrollView.rightAnchor)
        .withPriority(.defaultHigh),
      tabsContainer.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
      
      indicatorView.widthAnchor.constraint(equalToConstant: .indicatorViewWidth),
      indicatorView.heightAnchor.constraint(equalToConstant: .indicatorViewHeight),
      indicatorView.topAnchor.constraint(equalTo: tabsContainer.bottomAnchor)
        .withPriority(.defaultLow)
    ])
  }
  
  func selectTabAt(index: Int, animated: Bool) {
    _selectedIndex = index
    
    layoutIfNeeded()
    tabs.enumerated().forEach {
      $0.element.isSelected = index == $0.offset
    }
    let frame = scrollView.convert(tabs[index].frame, from: tabsContainer)
    indicatorViewCenterXConstraint?.constant = frame.midX - .indicatorViewWidth/2
    if animated {
      UIView.animate(withDuration: 0.2) {
        self.layoutIfNeeded()
      }
    }
  }
}

private extension CGFloat {
  static let indicatorViewWidth: CGFloat = 24
  static let indicatorViewHeight: CGFloat = 3
  static let height: CGFloat = 64
}

