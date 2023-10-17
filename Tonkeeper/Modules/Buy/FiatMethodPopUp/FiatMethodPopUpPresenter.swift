//
//  FiatMethodPopUpPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 16.10.23..
//

import Foundation
import WalletCore

final class FiatMethodPopUpPresenter {
  
  // MARK: - Module
  
  weak var viewInput: FiatMethodPopUpViewInput?
  weak var output: FiatMethodPopUpModuleOutput?
  
  // MARK: - Dependencies
  
  private let fiatMethodItem: FiatMethodViewModel
  private let fiatMethodsController: FiatMethodsController
  
  init(fiatMethodItem: FiatMethodViewModel,
       fiatMethodsController: FiatMethodsController) {
    self.fiatMethodItem = fiatMethodItem
    self.fiatMethodsController = fiatMethodsController
  }
}

// MARK: - FiatMethodPopUpPresenterInput

extension FiatMethodPopUpPresenter: FiatMethodPopUpPresenterInput {
  func viewDidLoad() {
    updateContent()
  }
}

// MARK: - FiatMethodPopUpModuleInput

extension FiatMethodPopUpPresenter: FiatMethodPopUpModuleInput {}

// MARK: - Private

private extension FiatMethodPopUpPresenter {
  func updateContent() {
    let header = ModalContentViewController.Configuration.Header(
      image: .url(fiatMethodItem.iconURL),
      imageShape: .roundedRect(cornerRadius: 20),
      title: fiatMethodItem.title,
      bottomDescription: fiatMethodItem.description)
    
    let actionBar = ModalContentViewController.Configuration.ActionBar(
      items: [
        .buttons([ModalContentViewController.Configuration.ActionBar.Button(
          title: fiatMethodItem.buttonTitle,
          configuration: .primaryLarge,
          tapAction: { [weak self] _ in
            guard let self = self else { return }
            Task {
              guard let url = await self.fiatMethodsController.urlForMethod(self.fiatMethodItem) else { return }
              await MainActor.run {
                self.output?.fiatMethodPopUpModule(self, openURL: url)
              }
            }
          }
        )])
      ]
    )
    
    let configuration = ModalContentViewController.Configuration(
      header: header,
      listItems: [],
      actionBar: actionBar
    )
    
    viewInput?.updateContent(configuration: configuration)
  }
}
