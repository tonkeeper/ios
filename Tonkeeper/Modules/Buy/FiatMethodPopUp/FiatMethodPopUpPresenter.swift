//
//  FiatMethodPopUpPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 16.10.23..
//

import Foundation
import WalletCore
import TKCore

final class FiatMethodPopUpPresenter {
  
  // MARK: - Module
  
  weak var viewInput: FiatMethodPopUpViewInput?
  weak var output: FiatMethodPopUpModuleOutput?
  
  // MARK: - Dependencies
  
  private let fiatMethodItem: FiatMethodViewModel
  private let fiatMethodsController: FiatMethodsController
  private let urlOpener: URLOpener
  private let appSettings = AppSettings()
  
  init(fiatMethodItem: FiatMethodViewModel,
       fiatMethodsController: FiatMethodsController,
       urlOpener: URLOpener) {
    self.fiatMethodItem = fiatMethodItem
    self.fiatMethodsController = fiatMethodsController
    self.urlOpener = urlOpener
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
    
    let warningButtons: [ModalContentViewController.Configuration.ActionBar.Warning.Button] = fiatMethodItem
      .infoButtons.map { buttonModel in .init(title: buttonModel.title) { [weak self] in
        guard let string = buttonModel.url,
              let url = URL(string: string) else { return }
        self?.urlOpener.open(url: url)
    }}
    
    let actionBar = ModalContentViewController.Configuration.ActionBar(
      items: [
        .warning(ModalContentViewController.Configuration.ActionBar.Warning(
          text: .externalWarningText,
          buttons: warningButtons
          )
        ),
        .buttons([ModalContentViewController.Configuration.ActionBar.Button(
          title: fiatMethodItem.actionButton?.title,
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
        )]),
        .checkmark(ModalContentViewController.Configuration.ActionBar.Checkmark(
          title: .checkmarkTitle,
          isMarked: false,
          markAction: { [weak self] isMarked in
            guard let self = self else { return }
            self.appSettings.setIsFiatMethodPopUpMarkedDoNotShow(for: self.fiatMethodItem.id, isNeed: isMarked)
          })
        )
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

private extension String {
  static let checkmarkTitle = "Do not show again"
  static let externalWarningText = "You are opening an external app not operated by Tonkeeper."
}
