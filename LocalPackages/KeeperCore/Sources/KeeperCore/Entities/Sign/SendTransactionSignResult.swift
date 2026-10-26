import Foundation

@frozen public enum SendTransactionSignResult {
    case response(String)
    case error(TonConnect.SendResponseError.ErrorCode)
}
