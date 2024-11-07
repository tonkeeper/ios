import Foundation
import TonSwift

public struct AccountEventModel {
  public struct Action {
    public enum ActionType {
      case sent
      case receieved
      case mint
      case burn
      case depositStake
      case withdrawStake
      case withdrawStakeRequest
      case spam
      case jettonSwap
      case bounced
      case subscribed
      case unsubscribed
      case walletInitialized
      case contractExec
      case nftCollectionCreation
      case nftCreation
      case removalFromSale
      case nftPurchase
      case bid
      case putUpForAuction
      case endOfAuction
      case putUpForSale
      case domainRenew
      case unknown
    }
    
    public struct ActionNFT {
      public let nft: NFT
      public let name: String?
      public let collectionName: String?
      public let image: URL?
    }
    
    public enum EncryptedComment {
      case encrypted(EncryptedCommentPayload)
      case decrypted(String?)
    }
    
    public let eventType: ActionType
    public let amount: String?
    public let subamount: String?
    public let leftTopDescription: String?
    public let leftBottomDescription: String?
    public let rightTopDescription: String?
    public let status: String?
    public let comment: String?
    public let encryptedComment: EncryptedComment?
    public let description: String?
    public let nft: ActionNFT?
    public let stakingImplementation: StakingPoolImplementation?
    
    init(eventType: ActionType,
         stakingImplementation: StakingPoolImplementation? = nil,
         amount: String?,
         subamount: String?,
         leftTopDescription: String?,
         leftBottomDescription: String?,
         rightTopDescription: String?,
         status: String?,
         comment: String?,
         encryptedComment: EncryptedComment? = nil,
         description: String? = nil,
         nft: ActionNFT?) {
      self.eventType = eventType
      self.amount = amount
      self.subamount = subamount
      self.leftTopDescription = leftTopDescription
      self.leftBottomDescription = leftBottomDescription
      self.rightTopDescription = rightTopDescription
      self.status = status
      self.comment = comment
      self.encryptedComment = encryptedComment
      self.description = description
      self.nft = nft
      self.stakingImplementation = stakingImplementation
    }
  }
  
  public let eventId: String
  public let actions: [Action]
  public let accountEvent: AccountEvent
  public let date: Date
}
