import UIKit

public enum TKCollectionSupplementaryItem: String {
  case header = "TKCollectionSupplementaryItem.Header"
  case footer = "TKCollectionSupplementaryItem.Footer"
  
  var kind: String {
    rawValue
  }
}
