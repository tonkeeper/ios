import UIKit
import TKUIKit
import TKLocalize
import KeeperCore

protocol BatteryPromocodeInputModuleOutput: AnyObject {
  var didUpdateResolvingState: ((BatteryPromocodeResolveState) -> Void)? { get set }
}

final class BatteryPromocodeInputViewController: UIViewController, BatteryPromocodeInputModuleOutput {
  
  var isInputEditing: Bool = false
  
  var didUpdateResolvingState: ((BatteryPromocodeResolveState) -> Void)?
  
  lazy var promocodeTextInputControl: TKTextInputTextFieldControl = {
    let textInputControl = TKTextInputTextFieldControl()
    return textInputControl
  }()
  
  lazy var promocodeTextField: TKTextField = {
    return TKTextField(
      textFieldInputView: TKTextFieldInputView(
        textInputControl: promocodeTextInputControl
      )
    )
  }()
  let promocodePasteButton = TKButton()
  let loaderView = TKLoaderView(size: .small, style: .primary)
  
  private var resolvingState: BatteryPromocodeResolveState = .none {
    didSet {
      didUpdateResolveState()
      didUpdateResolvingState?(resolvingState)
    }
  }
  private var resolvingTask: Task<Void, Never>?
  
  private let wallet: Wallet
  private let batteryService: BatteryService
  private let batteryPromocodeStore: BatteryPromocodeStore
  
  init(wallet: Wallet,
       batteryService: BatteryService,
       batteryPromocodeStore: BatteryPromocodeStore) {
    self.wallet = wallet
    self.batteryService = batteryService
    self.batteryPromocodeStore = batteryPromocodeStore
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    batteryPromocodeStore.addObserver(self) { observer, _ in
      DispatchQueue.main.async {
        observer.resolvingState = observer.batteryPromocodeStore.state
      }
    }
    resolvingState = batteryPromocodeStore.state
  }
  
  private func setup() {
    promocodeTextInputControl.autocorrectionType = .no
    promocodeTextInputControl.returnKeyType = .done
    promocodeTextInputControl.delegate = self
    promocodeTextField.placeholder = TKLocales.Battery.Refill.promocode
    promocodeTextField.didBeginEditing = { [weak self] in
      self?.isInputEditing = true
    }
    promocodeTextField.didEndEditing = { [weak self] in
      guard let self else { return }
      self.isInputEditing = false
      let text = self.promocodeTextField.text
      resolve(text: text)
    }
    promocodeTextField.didUpdateText = { [weak self] _ in
      self?.promocodeTextField.isValid = true
      self?.resolvingState = .none
    }
    updateTextFieldRightItems()
    
    var configuration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .tertiary)
    configuration.content.title = .plainString(TKLocales.Actions.paste)
    configuration.action = { [weak self] in
      guard let pasteboardString = UIPasteboard.general.string else { return }
      self?.promocodeTextField.text = pasteboardString
      self?.promocodeTextField.resignFirstResponder()
    }
    promocodePasteButton.configuration = configuration
    
    view.addSubview(promocodeTextField)
    promocodeTextField.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }
  }
  
  private func resolve(text: String?) {
    if let resolvingTask {
      resolvingTask.cancel()
    }
    
    batteryPromocodeStore.setResolveState(.none)
    
    guard let text, !text.isEmpty else {
      return
    }
    
    resolvingTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await batteryPromocodeStore.setResolveState(.resolving(promocode: text))
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      guard !Task.isCancelled else { return }
      do {
        try await batteryService.verifyPromocode(wallet: wallet, promocode: text)
        await batteryPromocodeStore.setResolveState(.success(promocode: text))
      } catch {
        await batteryPromocodeStore.setResolveState(.failed)
      }
    }
  }
  
  private func didUpdateResolveState() {
    switch resolvingState {
    case .none:
      promocodeTextField.isValid = true
    case .success(let promocode):
      promocodeTextField.isValid = true
      promocodeTextField.text = promocode
    case .failed:
      promocodeTextField.isValid = false
    case .resolving(let promocode):
      promocodeTextField.isValid = true
      promocodeTextField.text = promocode
    }
    updateTextFieldRightItems()
  }
  
  private func updateTextFieldRightItems() {
    var rightItems = [TKTextField.RightItem]()
    rightItems.append(TKTextField.RightItem(view: promocodePasteButton, mode: .empty))
    switch resolvingState {
    case .success:
      let tickView = UIImageView()
      tickView.tintColor = .Accent.green
      tickView.image = .TKUIKit.Icons.Size28.donemarkOutline
      tickView.contentMode = .center
      rightItems.append(
        TKTextField.RightItem(
          view: tickView,
          mode: .nonEmpty,
          padding: UIEdgeInsets(
            top: 0,
            left: 8,
            bottom: 0,
            right: 8
          )
        )
      )
    case .resolving:
      rightItems.append(
        TKTextField.RightItem(
          view: loaderView,
          mode: .nonEmpty,
          padding: UIEdgeInsets(
            top: 0,
            left: 8,
            bottom: 0,
            right: 8
          )
        )
      )
    default: break
    }
    
    promocodeTextField.rightItems = rightItems
  }
}

extension BatteryPromocodeInputViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}
