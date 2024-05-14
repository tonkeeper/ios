import Foundation
import BigInt

public final class TokenPickerController {
  
  public struct TokenModel {
    public let image: TokenImage
    public let identifier: String
    public let name: String
    public let balance: String
  }
  
  public var didUpdateTokens: (([TokenModel]) -> Void)?
  public var didUpdateSelectedTokenIndex: ((Int) -> Void)?
  
  private var tokens = [Token]()
 
  private let wallet: Wallet
  private let selectedToken: Token
  private let walletBalanceStore: WalletBalanceStore
  private let amountFormatter: AmountFormatter
  
  init(wallet: Wallet, 
       selectedToken: Token,
       walletBalanceStore: WalletBalanceStore,
       amountFormatter: AmountFormatter) {
    self.wallet = wallet
    self.selectedToken = selectedToken
    self.walletBalanceStore = walletBalanceStore
    self.amountFormatter = amountFormatter
  }
  
  public func start() async {
    _ = await walletBalanceStore.addEventObserver(self) { observer, event in
      switch event {
      case .balanceUpdate(_, let wallet):
        guard (try? wallet.friendlyAddress) == (try? observer.wallet.friendlyAddress) else {
          return
        }
        Task { await observer.reloadTokens() }
      }
    }
    await reloadTokens()
  }
  
  public func getTokenAt(index: Int) -> Token {
    guard tokens.count > index else { return .ton }
    return tokens[index]
  }
  
  public func isTokenSelectedAt(index: Int) -> Bool {
    guard tokens.count > index else { return false }
    return selectedToken == tokens[index]
  }
}

private extension TokenPickerController {
  func reloadTokens() async {
    let balance: Balance
    do {
      balance = try await walletBalanceStore.getBalanceState(wallet: wallet).walletBalance.balance
    } catch {
      balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
    }
    
    await MainActor.run {
      self.tokens = CollectionOfOne(Token.ton) + balance.jettonsBalance.map { Token.jetton($0.item) }
    }
    
    let tonFormattedBalance = amountFormatter.formatAmount(
      BigUInt(balance.tonBalance.amount),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      symbol: TonInfo.symbol
    )
    let tonModel = TokenModel(
      image: .ton,
      identifier: "Toncoin",
      name: TonInfo.name,
      balance: tonFormattedBalance
    )
    
    let jettonModels = balance.jettonsBalance.map { jettonBalance in
      let formattedBalance = amountFormatter.formatAmount(
        jettonBalance.quantity,
        fractionDigits: jettonBalance.item.jettonInfo.fractionDigits,
        maximumFractionDigits: 2,
        symbol: jettonBalance.item.jettonInfo.symbol
      )
      return TokenModel(
        image: .url(jettonBalance.item.jettonInfo.imageURL),
        identifier: jettonBalance.item.jettonInfo.address.toRaw(),
        name: jettonBalance.item.jettonInfo.name,
        balance: formattedBalance
      )
    }
    
    await MainActor.run {
      didUpdateTokens?(CollectionOfOne(tonModel) + jettonModels)
      
      switch selectedToken {
      case .ton:
        didUpdateSelectedTokenIndex?(0)
      case .jetton(let jettonItem):
        guard let index = balance.jettonsBalance.firstIndex(where: { $0.item == jettonItem }) else { return }
        didUpdateSelectedTokenIndex?(index + 1)
      }
    }
  }
}
