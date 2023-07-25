//
//  SendAmountSendAmountViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import UIKit

class SendAmountViewController: GenericViewController<SendAmountView> {

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
    enterAmountViewController.becomeFirstResponder()
  }
}

// MARK: - SendAmountViewInput

extension SendAmountViewController: SendAmountViewInput {
  func updateTitleView(model: SendAmountTitleView.Model) {
    titleView.configure(model: model)
  }
  
  func updateRemainingLabel(attributedString: NSAttributedString?) {
    enterAmountViewController.customView.remainingLabel.attributedText = attributedString
  }
  
  func selectMaxButton() {
    enterAmountViewController.customView.maxButton.configuration = .primarySmall
  }
  
  func deselectMaxButton() {
    enterAmountViewController.customView.maxButton.configuration = .secondarySmall
  }
  
  func updatePrimaryCurrency(_ value: String?, currencyCode: String?) {
    enterAmountViewController.updatePrimaryCurrencyValue(value,
                                                         currencyCode: currencyCode)
  }
  
  func updateSecondaryCurrency(_ string: String?) {
    enterAmountViewController.updateSecondaryCurrencyButtonTitle(string)
  }
  
  func updateContinueButtonAvailability(_ isAvailable: Bool) {
    customView.continueButton.isEnabled = isAvailable
  }
  
  func showActivity() {
    customView.continueButtonActivityContainer.showActivity()
  }
  
  func hideActivity() {
    customView.continueButtonActivityContainer.hideActivity()
  }
  
  func showTokenSelectionButton(_ code: String) {
    enterAmountViewController.customView.tokenSelectionButton.isHidden = false
    enterAmountViewController.customView.tokenSelectionButton.title = code
  }
  
  func hideTokenSelectionButton() {
    enterAmountViewController.customView.tokenSelectionButton.isHidden = true
  }
  
  func showMenu(items: [TKMenuItem]) {
    TKMenuController.show(sourceView: enterAmountViewController.customView.tokenSelectionButton,
                          items: items) { [weak self] index in
      self?.deselectMaxButton()
      self?.presenter.didSelectToken(at: index)
    }
  }
}

extension SendAmountViewController: TKKeyboardViewDelegate, TKKeyboardViewFractionalDelegate {
  func keyboard(_ keyboard: TKKeyboardView, didTapDigit digit: Int) {
    enterAmountViewController.setInput("\(digit)")
  }
  
  func keyboardDidTapBackspace(_ keyboard: TKKeyboardView) {
    enterAmountViewController.deleteBackward()
  }
  
  func keyboard(_ keyboard: TKKeyboardView, didTapDecimalSeparator separator: String) {
    enterAmountViewController.setInput("\(separator)")
  }
}

// MARK: - Private

private extension SendAmountViewController {
  func setup() {
    navigationItem.titleView = titleView
  
    setupCloseButton { [weak self] in
      self?.presenter.didTapCloseButton()
    }
    
    customView.continueButton.addAction(.init(handler: { [weak self] in
      self?.presenter.didTapContinueButton()
    }), for: .touchUpInside)
    
    customView.keyboardView.delegate = self
    
    setupEnterAmount()
  }
  
  func setupEnterAmount() {
    addChild(enterAmountViewController)
    customView.embedEnterAmountView(enterAmountViewController.view)
    enterAmountViewController.didMove(toParent: self)
    
    enterAmountViewController.formatController = presenter.amountInputFormatController
    enterAmountViewController.customView.maxButton.addAction(.init(handler: { [weak self] in
      self?.presenter.didTapMaxButton()
    }), for: .touchUpInside)
    
    enterAmountViewController.customView.secondaryCurrencyButton.addTarget(
      self,
      action: #selector(didTapSwapCurrency),
      for: .touchUpInside
    )
    
    enterAmountViewController.didChangeText = { [weak self] text in
      guard let self = self else { return }
      self.deselectMaxButton()
      self.presenter.didChangeAmountText(text: text)
    }
    
    enterAmountViewController.didTapTokenButton = { [weak self] in
      self?.presenter.didTapSelectTokenButton()
    }
  }
  
  @objc
  func didTapSwapCurrency() {
    presenter.didTapSwapButton()
  }
}
