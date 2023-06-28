//
//  WelcomeWelcomePresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import UIKit

final class WelcomePresenter {
  
  // MARK: - Module
  
  weak var viewInput: WelcomeViewInput?
  weak var output: WelcomeModuleOutput?
}

// MARK: - WelcomePresenterIntput

extension WelcomePresenter: WelcomePresenterInput {
  func viewDidLoad() {
    updateContent()
  }
  
  func didTapContinueButton() {
    output?.didTapContinueButton()
  }
}

// MARK: - WelcomeModuleInput

extension WelcomePresenter: WelcomeModuleInput {}

// MARK: - Private

private extension WelcomePresenter {
  func updateContent() {
    let model = WelcomeView.Model(title: createTitleString(), items: createItems(), buttonTitle: "Get started")
    viewInput?.update(with: model)
  }
  
  func createTitleString() -> NSAttributedString {
    let attributedTitle = String.title
      .attributed(with: .h1, alignment: .left, lineBreakMode: .byWordWrapping, color: .Text.primary)
    let coloredRange = String.title.range(of: String.coloredSubstring)
    guard let coloredRange = coloredRange else { return attributedTitle }
    let nsColoredRange = NSRange(coloredRange, in: String.title)
    let mutableAttributedTitle = NSMutableAttributedString(attributedString: attributedTitle)
    mutableAttributedTitle.addAttributes([.foregroundColor: UIColor.Text.accent.cgColor], range: nsColoredRange)
    return mutableAttributedTitle
  }
  
  func createItems() -> [WelcomeListItem.Model] {
    let firstTitle = "World-class speed"
      .attributed(with: .label1, alignment: .left, color: .Text.primary)
    let firstDescription = "TON is a network designed for speed and throughput. Fees are significantly lower than on other blockchains, and transactions are confirmed in a matter of seconds."
      .attributed(with: .body2, alignment: .left, color: .Text.secondary)
    let firstIcon = UIImage.Icons.Welcome.speed
    
    let secondTitle = "End-to-end security"
      .attributed(with: .label1, alignment: .left, color: .Text.primary)
    let secondDescription = "Tonkeeper stores your cryptographic keys on your device without requiring documents, personal information, contact details, or KYC."
      .attributed(with: .body2, alignment: .left, color: .Text.secondary)
    let secondIcon = UIImage.Icons.Welcome.security
    
    return [
      .init(title: firstTitle, description: firstDescription, icon: firstIcon),
      .init(title: secondTitle, description: secondDescription, icon: secondIcon)
    ]
  }
}

private extension String {
  static let title = "Welcome\nto Tonkeeper"
  static let coloredSubstring = "Tonkeeper"
}
