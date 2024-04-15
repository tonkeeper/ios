import Foundation
import KeeperCore
import TKCore
import UIKit
import TKUIKit

protocol TonConnectConfirmationModuleOutput: AnyObject {
  var didTapConfirmButton: (() async -> Bool)? { get set }
  var didTapCancelButton: (() -> Void)?  { get set }
  var didConfirm: (() -> Void)? { get set }
}

protocol TonConnectConfirmationViewModel: AnyObject {
  var contentView: ((TonConnectConfirmationContentView.Model) -> TonConnectConfirmationContentView)? { get set }
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  var didUpdateHeader: ((String, String?) -> Void)? { get set }
  
  func viewDidLoad()
}

final class TonConnectConfirmationViewModelImplementation: TonConnectConfirmationViewModel, TonConnectConfirmationModuleOutput {
  
  // MARK: - TonConnectConfirmationModuleOutput
  
  var didTapConfirmButton: (() async -> Bool)?
  var didTapCancelButton: (() -> Void)?
  var didConfirm: (() -> Void)?
  
  // MARK: - TonConnectConfirmationViewModel
  
  var contentView: ((TonConnectConfirmationContentView.Model) -> TonConnectConfirmationContentView)?
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  var didUpdateHeader: ((String, String?) -> Void)?
  
  func viewDidLoad() {
    didUpdateHeader?(
      "Confirm Action",
      "Wallet: \(model.walletName)"
    )
    prepareContent()
  }
  
  // MARK: - Dependencies
  
  private let model: TonConnectConfirmationController.Model
  private let historyEventMapper: HistoryEventMapper
  
  init(model: TonConnectConfirmationController.Model,
       historyEventMapper: HistoryEventMapper) {
    self.model = model
    self.historyEventMapper = historyEventMapper
  }
}

private extension TonConnectConfirmationViewModelImplementation {
  func prepareContent() {
    var contentItems = [TKModalCardViewController.Configuration.ContentItem]()
    if let contentItem = contentItem() {
      contentItems.append(.item(contentItem))
    }
    
    let actionBarItems: [TKModalCardViewController.Configuration.Item] = [
      .buttonsRow(.init(buttons: [
        cancelButton(),
        confirmButton()
      ]), bottomSpacing: 16, itemSpacing: 8)
    ]
    let configuration = TKModalCardViewController.Configuration(
      header: .init(items: []),
      content: .init(items: contentItems),
      actionBar: .init(items: actionBarItems)
    )
    didUpdateConfiguration?(configuration)
  }
  
  func confirmButton() -> TKModalCardViewController.Configuration.Button {
    TKModalCardViewController.Configuration.Button(
      title: "Confirm",
      size: .large,
      category: .primary,
      isEnabled: true,
      isActivity: false,
      tapAction: { [weak self] isActivityClosure, isSuccessClosure in
        guard let self = self else { return }
        isActivityClosure(true)
        Task {
          let isSuccess = await self.didTapConfirmButton?() ?? false
          await MainActor.run {
            isSuccessClosure(isSuccess)
          }
        }
      },
      completionAction: { [weak self] isSuccess in
        guard isSuccess else { return }
        self?.didConfirm?()
      })
  }
  
  func cancelButton() -> TKModalCardViewController.Configuration.Button {
    TKModalCardViewController.Configuration.Button(
      title: "Cancel",
      size: .large,
      category: .secondary,
      isEnabled: true,
      isActivity: false,
      tapAction: { [weak self] _, _ in
        self?.didTapCancelButton?()
      },
      completionAction: { [weak self] _ in
        self?.didTapCancelButton?()
      })
  }
  
  func contentItem() -> TKModalCardViewController.Configuration.Item? {
    let model = TonConnectConfirmationContentView.Model(
      actionsConfiguration: mapEvent(model.event),
      feeModel: .init(title: "Network fee", fee: model.fee)
    )
    guard let view = contentView?(model) else { return nil }
    return .customView(view, bottomSpacing: 32)
  }
  
  func mapEvent(_ event: HistoryEvent) -> HistoryCellContentView.Configuration {
    return historyEventMapper.mapEventContentConfiguration(event, nftAction: { _ in }, tapAction: { _ in })
  }
}
