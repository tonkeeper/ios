import UIKit

public struct TKSwapTokenFieldState {
  public struct Token {
    let image: TKSwapTokenFieldTokenView.Image
    let name: String
    let balance: String
    public init(image: TKSwapTokenFieldTokenView.Image, name: String, balance: String) {
      self.image = image
      self.name = name
      self.balance = balance
    }
  }
  public enum Status {
    case active
    case inactive
    case error
  }
  var status = Status.inactive

  let isSellingToken: Bool
  let previewMode: Bool
  let title: String
  let token: Token?
  let amount: String
  
  public init(isSellingToken: Bool = false,
              previewMode: Bool = false,
              status: Status = Status.inactive,
              title: String = "",
              token: Token? = Token(image: .image(UIImage()), name: "", balance: ""),
              amount: String = "") {
    self.isSellingToken = isSellingToken
    self.previewMode = previewMode
    self.status = status
    self.title = title
    self.token = token
    self.amount = amount
  }

  var backgroundColor: UIColor {
    switch status {
    case .inactive:
      return .Field.background
    case .active:
      return .Field.background
    case .error:
      return .Field.errorBackground
    }
  }
  
  var borderColor: UIColor {
    switch status {
    case .inactive:
      return UIColor.clear
    case .active:
      return UIColor.Field.activeBorder
    case .error:
      return UIColor.Field.errorBorder
    }
  }
}
