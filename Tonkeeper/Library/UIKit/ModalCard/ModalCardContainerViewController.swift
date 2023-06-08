//
//  ModalCardContainerViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 8.6.23..
//

import UIKit

final class ModalCardContainerViewController: GenericViewController<ModalCardContainerView> {
  override var transitioningDelegate: UIViewControllerTransitioningDelegate? {
    get { dimmingTransitioningDelegate }
    set {}
  }
  
  override var modalPresentationStyle: UIModalPresentationStyle {
    get { .custom }
    set {}
  }
  
  private let dimmingTransitioningDelegate = DimmingTransitioningDelegate()
  private let content: ModalCardContainerContent
  private let panGestureRecognizer = UIPanGestureRecognizer()
  
  // MARK: - State
  
  private var cachedHeight: CGFloat = 0
  
  // MARK: - Init
  
  init(content: ModalCardContainerContent) {
    self.content = content
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard cachedHeight != view.bounds.height else { return }
    cachedHeight = view.bounds.height
    customView.layoutIfNeeded()
    updateContentHeight()
  }
}

private extension ModalCardContainerViewController {
  func setup() {
    setupContent()
    setupGestures()
  }
  
  func setupContent() {
    addChild(content)
    customView.addContentView(content.view)
    content.didMove(toParent: self)
    
    content.didUpdateHeight = { [weak self] in
      self?.panGestureRecognizer.isEnabled = false
      self?.updateContentHeight()
      self?.panGestureRecognizer.isEnabled = true
    }
  }
  
  func updateContentHeight() {
    let contentHeight = content.height
    customView.contentHeight = contentHeight
    animateLayout()
  }
  
  func setupGestures() {
    setupPanGesture()
  }
  
  func setupPanGesture() {
    panGestureRecognizer.addTarget(
      self,
      action: #selector(panGestureHandler(_:))
    )
    customView.addGestureRecognizer(panGestureRecognizer)
  }
  
  func animateLayout() {
    UIView.animate(
        withDuration: 0.4,
        delay: .zero,
        usingSpringWithDamping: 2,
        initialSpringVelocity: 0,
        options: .curveEaseInOut,
        animations: customView.layoutIfNeeded
    )
  }
}

private extension ModalCardContainerViewController {
  @objc
  func panGestureHandler(_ recognizer: UIPanGestureRecognizer) {
    let yTranslation = recognizer.translation(in: recognizer.view).y
    let dragOffset = max(-.maximumDragOffset, yTranslation * .dragOffsetCoefficient)
    switch recognizer.state {
    case .changed:
      didDrag(with: dragOffset)
    case .ended:
      let yVelocity = recognizer.velocity(in: recognizer.view).y
      didEndDragging(offset: dragOffset, velocity: yVelocity)
    case .cancelled, .failed:
      didEndDragging(offset: 0, velocity: 0)
    default:
      break
    }
  }
  
  func didDrag(with offset: CGFloat) {
    customView.dragOffset = offset
  }
  
  func didEndDragging(offset: CGFloat, velocity: CGFloat) {
    let dragDistance = offset / customView.contentHeight
    let isDismiss = dragDistance >= .dragTreshold || velocity >= .velocityTreshold
    if isDismiss {
      dismiss(animated: true)
    } else {
      customView.dragOffset = 0
      animateLayout()
    }
  }
}

private extension CGFloat {
  static let maximumDragOffset: CGFloat = 20
  static let dragOffsetCoefficient: CGFloat = 1/2
  static let dragTreshold: CGFloat = 1/3
  static let velocityTreshold: CGFloat = 1500
}
