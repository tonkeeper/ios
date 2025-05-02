import Foundation
import TKLocalize
import KeeperCore
import BigInt
import TonSwift

struct HistoryEventDetailsModel {
  enum HeaderImage {
    case transfer(TransactionConfirmationHeaderImageItem)
    case swap(fromImage: TokenImage, toImage: TokenImage)
  }
  
  public struct NFT {
    public let name: String?
    public let collectionName: String?
    public let isVerified: Bool
  }
  
  public enum EncryptedComment {
    case encrypted(payload: EncryptedCommentPayload)
    case decrypted(String?)
  }
  
  struct Management {
    let state: TransactionsManagement.TransactionState?
    let isManagementAvailable: Bool
  }
  
  enum ListItem {
    case recipient(value: String, copyValue: String)
    case recipientAddress(value: String, copyValue: String)
    case sender(value: String, copyValue: String)
    case senderAddress(value: String, copyValue: String)
    case extra(value: String, isRefund: Bool, converted: String?)
    case refund(value: String, converted: String?)
    case comment(String)
    case encryptedComment(EncryptedComment)
    case description(String)
    case operation(String)
    case other(title: String, value: String, copyValue: String?)
  }
  
  struct TransasctionDetailsButton {
    let buttonTitle: NSAttributedString
    let url: URL
    let browserTitle: String
    let hash: String
  }
  
  let headerImage: HeaderImage?
  let title: String?
  let aboveTitle: String?
  let date: String?
  let fiatPrice: String?
  let nftModel: NFT?
  let status: String?
  let isScam: Bool
  let management: Management?
  let listItems: [ListItem]
  let detailsButton: TransasctionDetailsButton?
  
  init(headerImage: HeaderImage? = nil,
       title: String? = nil,
       aboveTitle: String? = nil,
       date: String? = nil,
       fiatPrice: String? = nil,
       nftModel: NFT? = nil,
       status: String? = nil,
       isScam: Bool,
       management: Management? = nil,
       listItems: [ListItem] = [],
       detailsButton: TransasctionDetailsButton?) {
    self.headerImage = headerImage
    self.title = title
    self.aboveTitle = aboveTitle
    self.date = date
    self.fiatPrice = fiatPrice
    self.nftModel = nftModel
    self.status = status
    self.isScam = isScam
    self.management = management
    self.listItems = listItems
    self.detailsButton = detailsButton
  }
}
