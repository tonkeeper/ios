//
//  SendAmountSendAmountViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import UIKit

class SendAmountViewController: GenericViewController<SendAmountView>, KeyboardObserving {

  // MARK: - Module

  private let presenter: SendAmountPresenterInput
  
  private let titleView = SendAmountTitleView()
  private let enterAmountViewController = EnterAmountViewController()

  // MARK: - Init

  init(presenter: SendAmountPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    registerForKeyboardEvents()
    enterAmountViewController.becomeFirstResponder()
  }
  
  // MARK: - Keyboard
  
  func keyboardWillShow(_ notification: Notification) {
    guard let keyboardSize = notification.keyboardSize,
    let duration = notification.keyboardAnimationDuration,
    let curve = notification.keyboardAnimationCurve else { return }
    customView.updateKeyboardHeight(keyboardSize.height,
                                    duration: duration,
                                    curve: curve)
  }
  
  func keyboardWillHide(_ notification: Notification) {
    guard let duration = notification.keyboardAnimationDuration,
    let curve = notification.keyboardAnimationCurve else { return }
    customView.updateKeyboardHeight(0,
                                    duration: duration,
                                    curve: curve)
  }
  
  func keyboardWillChangeFrame(_ notification: Notification) {
    guard let keyboardSize = notification.keyboardSize,
    let duration = notification.keyboardAnimationDuration,
    let curve = notification.keyboardAnimationCurve else { return }
    customView.updateKeyboardHeight(keyboardSize.height,
                                    duration: duration,
                                    curve: curve)
  }
}

// MARK: - SendAmountViewInput

extension SendAmountViewController: SendAmountViewInput {
  func updateTitleView(model: SendAmountTitleView.Model) {
    titleView.configure(model: model)
  }
  
  func updateRemainingLabel(string: String?) {
    enterAmountViewController.customView.remainingLabel.text = string
  }
  
  func selectMaxButton() {
    enterAmountViewController.customView.maxButton.configuration = .primarySmall
  }
  
  func deselectMaxButton() {
    enterAmountViewController.customView.maxButton.configuration = .secondarySmall
  }
  
  func updateInputCurrencyCode(_ code: String) {
    enterAmountViewController.customView.currencyLabel.text = code
  }
}

// MARK: - Private

private extension SendAmountViewController {
  func setup() {
    navigationItem.titleView = titleView
  
    setupCloseButton { [weak self] in
      self?.presenter.didTapCloseButton()
    }
    
    setupEnterAmount()
  }
  
  func setupEnterAmount() {
    enterAmountViewController.formatController = presenter.textFieldFormatController
    enterAmountViewController.customView.maxButton.addAction(.init(handler: { [weak self] in
      self?.presenter.didTapMaxButton()
    }), for: .touchUpInside)
    
    addChild(enterAmountViewController)
    customView.embedEnterAmountView(enterAmountViewController.view)
    enterAmountViewController.didMove(toParent: self)
    
    enterAmountViewController.didChangeText = { [weak self] text in
      guard let self = self else { return }
      self.presenter.didChangeAmountText(text: text)
    }
  }
}
