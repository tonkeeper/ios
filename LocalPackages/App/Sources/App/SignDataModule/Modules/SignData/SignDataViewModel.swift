import Foundation
import TKUIKit
import TKCore
import UIKit
import KeeperCore
import TKLocalize
import TonSwift

@MainActor
protocol SignDataModuleOutput: AnyObject {
  var didRequireSign: ((TonConnect.SignDataRequest, String, Wallet) async throws -> SignedDataResult?)? { get set }
  var didFail: ((Swift.Error) -> Void)? { get set }
  var didCancel: (() -> Void)? { get set }
  var didConfirm: (() -> Void)? { get set }
}

@MainActor
public protocol SignDataModuleInput: AnyObject {
  func cancel()
}

@MainActor
protocol SignDataViewModel: AnyObject {
  var didUpdateHeader: ((TKPullCardHeaderItem) -> Void)? { get set }
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
  
  var didTapCopy: ((String?) -> Void)? { get set }
  var showToast: ((ToastPresenter.Configuration) -> Void)? { get set }
    
  func viewDidLoad()
}

@MainActor
final class SignDataViewModelImplementation: SignDataViewModel, SignDataModuleOutput, SignDataModuleInput {
  
  // MARK: - SignDataModuleOutput
  
  var didRequireSign: ((KeeperCore.TonConnect.SignDataRequest, String, KeeperCore.Wallet) async throws -> SignedDataResult?)?
  var didFail: ((Swift.Error) -> Void)?
  var didCancel: (() -> Void)?
  var didConfirm: (() -> Void)?
  
  // MARK: - SignDataModuleInput
  
  public func cancel() {
    resultHandler.didCancel()
  }

  // MARK: - SignDataViewModel
  
  var didUpdateHeader: ((TKPullCardHeaderItem) -> Void)?
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
  
  var didTapCopy: ((String?) -> Void)?
  var showToast: ((ToastPresenter.Configuration) -> Void)?
  
  enum ConfirmationState {
    case idle
    case process
    case success
    case failed
  }
  
  var confirmationState: ConfirmationState = .idle {
    didSet {
      updateConfiguration()
    }
  }
    
  func viewDidLoad() {
    didUpdateHeader?(createHeaderItem())
    updateConfiguration()
  }
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let dappUrl: String
  private let signRequest: TonConnect.SignDataRequest
  private let resultHandler: SignDataResultHandler
  
  init(
    wallet: Wallet,
    dappUrl: String,
    signRequest: TonConnect.SignDataRequest,
    resultHandler: SignDataResultHandler
  ) {
    self.wallet = wallet
    self.dappUrl = dappUrl
    self.signRequest = signRequest
    self.resultHandler = resultHandler
  }
  
  private func createSliderItem() -> TKPopUp.Item {
    let sliderItem = TKPopUp.Component.Slider(
      title: TKLocales.SignData.Slider.title,
      isEnable: true,
      didConfirm: { [weak self] in
        self?.confirmSign()
      }
    )
    
    return TKPopUp.Component.Process(
      items: [
        TKPopUp.Component.GroupComponent(
          padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
          items: [
            sliderItem
          ]
        )
      ],
      state: {
        switch confirmationState {
        case .idle:
          return .idle
        case .process:
          return .process
        case .success:
          return .success
        case .failed:
          return .failed
        }
      }(),
      successTitle: TKLocales.Result.success,
      errorTitle: TKLocales.Result.failure
    )
  }
  
  private func updateConfiguration() {
    var items = [TKPopUp.Item]()
    items.append(createContentItem())
    items.append(createSliderItem())
    
    let configuration = TKPopUp.Configuration(
      items: items
    )
    didUpdateConfiguration?(configuration)
  }
  
  private func createContentItem() -> TKPopUp.Item {
    let content: TKPopUp.Item = {
      switch signRequest.params {
      case .text(let text):
        return SignDataTextContentView(with:
            .init(
              text: text,
              caption: TKLocales.SignData.caption,
              copyButtonContent: .init(title: .plainString(TKLocales.Actions.copy)),
              copyButtonAction: { [weak self] in
                self?.copyButtonAction(text: text)
              }
            )
        )
      case .binary(_):
        return UnknownContentView()
      case .cell(_, _):
        return UnknownContentView()
      }
    }()
    
    return TKPopUp.Component.GroupComponent(
      padding: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16),
      items: [
        content
      ]
    )
  }
  
  private func createHeaderItem() -> TKPullCardHeaderItem {
    let subtitleString = TKLocales.SignData.title.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    let walletString = "\(TKLocales.ConfirmSend.wallet): ".withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    let dotString = " · ".withTextStyle(
      .body2,
      color: .Text.tertiary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    let walletNameString = wallet.iconWithName(
      attributes: TKTextStyle.body2.getAttributes(
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ),
      iconColor: .Icon.primary,
      iconSide: 16
    )
    let subtitle = NSMutableAttributedString(attributedString: subtitleString)
    subtitle.append(dotString)
    subtitle.append(walletString)
    subtitle.append(walletNameString)
  
    
    return TKPullCardHeaderItem(
      title: .title(
        title: dappUrl,
        subtitle: subtitle
      )
    )
  }
  
  func copyButtonAction(text: String) {
    didTapCopy?(text)
    showToast?(wallet.copyToastConfiguration())
  }

  private func confirmSign() {
    Task {
      confirmationState = .process
      do {
        if let signedData = try await didRequireSign?(signRequest, dappUrl, wallet) {
          resultHandler.didSign(signedData: signedData)
          try? await Task.sleep(nanoseconds: 1_000_000_000)
          didConfirm?()
          confirmationState = .success
        } else {
          confirmationState = .failed
          try? await Task.sleep(nanoseconds: 1_000_000_000)
          confirmationState = .idle
        }
      } catch {
        confirmationState = .failed
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        confirmationState = .idle
        didFail?(error)
      }
    }
  }
}
