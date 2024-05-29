import Foundation

public enum SendTransactionSignResult {
  case response(String)
  case error(TonConnect.SendTransactionResponseError.ErrorCode)
}
