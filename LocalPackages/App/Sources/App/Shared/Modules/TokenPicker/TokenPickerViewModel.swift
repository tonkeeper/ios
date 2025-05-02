import Foundation
import KeeperCore
import TKUIKit
import TKCore
import BigInt
import TronSwift

protocol TokenPickerModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didSelectToken: ((TokenPickerModelState.PickerToken) -> Void)? { get set }
}

protocol TokenPickerViewModel: AnyObject {
  var didUpdateSelectedToken: ((Int?, _ scroll: Bool) -> Void)? { get set }
  var didUpdateSnapshot: ((_ snapshot: TokenPicker.Snapshot) -> Void)? { get set }
  
  func viewDidLoad()
}

final class TokenPickerViewModelImplementation: TokenPickerViewModel, TokenPickerModuleOutput {
  
  // MARK: - TokenPickerModuleOutput
  
  var didFinish: (() -> Void)?
  var didSelectToken: ((TokenPickerModelState.PickerToken) -> Void)?
  
  // MARK: - TokenPickerViewModel
  
  var didUpdateSelectedToken: ((Int?, _ scroll: Bool) -> Void)?
  var didUpdateSnapshot: ((_ snapshot: TokenPicker.Snapshot) -> Void)?
  
  func viewDidLoad() {
    tokenPickerModel.didUpdateState = { [weak self] state in
      self?.didUpdateState(state: state)
    }
    let state = tokenPickerModel.getState()
    self.didUpdateState(state: state)
  }
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()
  
  // MARK: - State
  
  private let syncQueue = DispatchQueue(label: "TokenPickerViewModelImplementationSyncQueue")
  
  // MARK: - Dependencies
  
  private let tokenPickerModel: TokenPickerModel
  private let appSettingsStore: AppSettingsStore
  private let amountFormatter: AmountFormatter
  
  // MARK: - Init
  
  init(tokenPickerModel: TokenPickerModel,
       appSettingsStore: AppSettingsStore,
       amountFormatter: AmountFormatter) {
    self.tokenPickerModel = tokenPickerModel
    self.appSettingsStore = appSettingsStore
    self.amountFormatter = amountFormatter
  }
}

private extension TokenPickerViewModelImplementation {
  func didUpdateState(state: TokenPickerModelState?) {
    syncQueue.async {
      guard let state else {
        DispatchQueue.main.async {
          self.didUpdateSnapshot?(TokenPicker.Snapshot())
        }
        return
      }
      let isSecureMode = self.appSettingsStore.getState().isSecureMode
      
      var items = [TokenPicker.Token]()
      let tonConfiguration: TKListItemCell.Configuration = {
        TokenPicker.mapListItemConfiguration(
          title: TonInfo.name,
          image: .image(.TKCore.Icons.Size44.tonLogo),
          tag: nil,
          caption: {
            if isSecureMode {
              return .secureModeValueShort
            } else {
              return self.amountFormatter.formatAmount(
                BigUInt(state.tonBalance.tonBalance.amount),
                fractionDigits: TonInfo.fractionDigits,
                maximumFractionDigits: 2,
                symbol: TonInfo.symbol
              )
            }
          }()
        )
      }()
      
      items.append(
        TokenPicker.Token(
          identifier: TonInfo.name,
          configuration: tonConfiguration,
          selectionHandler: { [weak self] in
            guard let self else { return }
            if case let .ton(ton) = state.selectedToken, case .ton = ton {
              self.didFinish?()
            } else {
              self.didSelectToken?(.ton(.ton))
              self.didFinish?()
            }
          }
        )
      )
      
      if let tronUSDTBalance = state.tronUSDTBalance {
        let configuration: TKListItemCell.Configuration = {
          TokenPicker.mapListItemConfiguration(
            title: TronSwift.USDT.name,
            image: .image(.App.Currency.Size44.usdt),
            tag: nil,
            caption: {
              if isSecureMode {
                return .secureModeValueShort
              } else {
                return self.amountFormatter.formatAmount(
                  tronUSDTBalance.amount,
                  fractionDigits: TonInfo.fractionDigits,
                  maximumFractionDigits: 2,
                  symbol: TronSwift.USDT.symbol
                )
              }
            }(),
            network: .trc20
          )
        }()
        
        let item = TokenPicker.Token(
          identifier: TronSwift.USDT.address.base58,
          configuration: configuration,
          selectionHandler: { [weak self] in
            guard let self else { return }
            if case .tronUSDT = state.selectedToken {
              self.didFinish?()
            } else {
              self.didSelectToken?(.tronUSDT)
              self.didFinish?()
            }
          }
        )
        items.append(item)
      }

      let sortedJettonBalances = state.jettonBalances
        .sorted(by: {
          $0.converted > $1.converted
        })
      
      let jettonItems = sortedJettonBalances
        .map { jettonBalance in
          let title = jettonBalance.jettonBalance.item.jettonInfo.symbol ?? jettonBalance.jettonBalance.item.jettonInfo.name
          let caption: String = {
            if isSecureMode {
              return .secureModeValueShort
            } else {
              return self.amountFormatter.formatAmount(
                jettonBalance.jettonBalance.quantity,
                fractionDigits: jettonBalance.jettonBalance.item.jettonInfo.fractionDigits,
                maximumFractionDigits: 2,
                symbol: jettonBalance.jettonBalance.item.jettonInfo.symbol
              )
            }
          }()
          let configuration = TokenPicker.mapListItemConfiguration(
            title: title,
            image: .urlImage(jettonBalance.jettonBalance.item.jettonInfo.imageURL),
            tag: nil,
            caption: caption,
            network: state.wallet.isTronTurnOn && jettonBalance.jettonBalance.item.jettonInfo.isTonUSDT ? .ton : nil
          )
          let item = TokenPicker.Token(
            identifier: jettonBalance.jettonBalance.item.jettonInfo.address.toRaw(),
            configuration: configuration,
            selectionHandler: { [weak self] in
              guard let self else { return }
              if case let .ton(ton) = state.selectedToken, case .jetton(let jettonItem) = ton, jettonItem == jettonBalance.jettonBalance.item {
                self.didFinish?()
              } else {
                self.didSelectToken?(.ton(.jetton(jettonBalance.jettonBalance.item)))
                self.didFinish?()
              }
            }
          )
          return item
        }
        
      items.append(contentsOf: jettonItems)
      
      var selectedIndex: Int?
      switch state.selectedToken {
      case .ton(let token):
        switch token {
        case .ton:
          selectedIndex = 0
        case .jetton(let jettonItem):
          selectedIndex = 0
          if let index = sortedJettonBalances.firstIndex(where: { $0.jettonBalance.item == jettonItem }) {
            selectedIndex = index + 1
          }
        }
      case .tronUSDT:
        selectedIndex = 1
      }
      
      var snapshot = TokenPicker.Snapshot()
      snapshot.appendSections([.tokens])
      snapshot.appendItems(items, toSection: .tokens)
      DispatchQueue.main.async {
        self.didUpdateSnapshot?(snapshot)
        self.didUpdateSelectedToken?(selectedIndex, state.scrollToSelected)
      }
    }
  }
}
