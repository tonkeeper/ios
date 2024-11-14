import UIKit
import TKUIKit
import TKLocalize
import KeeperCore

enum NFTDetailsManageNFTState {
  case visible
  case hidden
}

protocol NFTDetailsManageNFTOutput: AnyObject {
  var didUpdateState: (() -> Void)? { get set }
  var didMarkAsSpam: (() -> Void)? { get set }
  
  func getState() -> NFTDetailsManageNFTState
}

final class NFTDetailsManageNFTViewController: UIViewController, NFTDetailsManageNFTOutput {
  
  // MARK: - NFTDetailsManageNFTOutput
  
  var didUpdateState: (() -> Void)?
  var didMarkAsSpam: (() -> Void)?
  
  func getState() -> NFTDetailsManageNFTState {
    guard wallet.kind != .watchonly,
          nft.isUnverified,
          nftManagementStore.state.nftStates[getNftManagementItem()] != .approved else {
      return .hidden
    }
    
    return .visible
  }
  
  private var markSpamNFTTask: Task<Void, Never>?
  private var approveNFTTask: Task<Void, Never>?
  
  private let reportSpamButton = TKButton()
  private let notSpamButton = TKButton()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    stackView.spacing = 8
    return stackView
  }()
  
  private let wallet: Wallet
  private let nft: NFT
  private let nftManagementStore: WalletNFTsManagementStore
  private let nftService: NFTService
  
  init(wallet: Wallet,
       nft: NFT,
       nftManagementStore: WalletNFTsManagementStore,
       nftService: NFTService) {
    self.wallet = wallet
    self.nft = nft
    self.nftManagementStore = nftManagementStore
    self.nftService = nftService
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }

  private func setup() {
    view.addSubview(stackView)
    stackView.addArrangedSubview(reportSpamButton)
    stackView.addArrangedSubview(notSpamButton)

    setupButtons()
    setupConstraints()
  }

  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.equalTo(self.view).inset(8)
      make.left.right.equalTo(self.view).inset(16)
      make.bottom.equalTo(self.view).offset(-16)
    }
  }
  
  private func setupButtons() {
    var reportSpamButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary, 
      size: .medium
    )
    reportSpamButtonConfiguration.content = .init(title: .plainString(TKLocales.NftDetails.Actions.reportSpam))
    reportSpamButtonConfiguration.backgroundColors = [
      .normal: .Accent.orange,
      .highlighted: .Accent.orange.withAlphaComponent(0.64)
    ]
    reportSpamButtonConfiguration.action = { [weak self] in
      self?.markSpamNFT()
    }
    reportSpamButton.configuration = reportSpamButtonConfiguration
    
    var notSpamButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .medium
    )
    notSpamButtonConfiguration.content = .init(title: .plainString(TKLocales.NftDetails.Actions.notSpam))
    notSpamButtonConfiguration.action = { [weak self] in
      self?.approveNFT()
    }
    notSpamButton.configuration = notSpamButtonConfiguration
  }
  
  private func approveNFT() {
    guard approveNFTTask == nil else { return }
    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      await nftManagementStore.approveItem(self.getNftManagementItem())
      Task { [weak self] in
        guard let self else { return }
        do {
          try await nftService.changeSuspiciousState(nft, isTestnet: wallet.isTestnet, isScam: false)
          self.approveNFTTask = nil
        } catch {
          self.approveNFTTask = nil
        }
      }
    }
    approveNFTTask = task
  }
  
  private func markSpamNFT() {
    guard markSpamNFTTask == nil else { return }
    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      await nftManagementStore.spamItem(self.getNftManagementItem())
      didMarkAsSpam?()
      Task { [weak self] in
        guard let self else { return }
        do {
          try await nftService.changeSuspiciousState(nft, isTestnet: wallet.isTestnet, isScam: true)
          self.markSpamNFTTask = nil
        } catch {
          self.markSpamNFTTask = nil
        }
      }
    }
    markSpamNFTTask = task
  }
  
  private func getNftManagementItem() -> NFTManagementItem {
    if let collection = nft.collection {
      return .collection(collection.address)
    } else {
      return .singleItem(nft.address)
    }
  }
}
