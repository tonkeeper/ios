import Foundation

enum RestorePurchaseError: Int, Swift.Error {
    case receiptRefreshFailed
    case invalidReceipt
    case validationFailed
    case nothingToRestore
    case batteryPurchaseFailed
}
