import Foundation

public struct SendConfirmationModel {
  public enum Image {
    case ton
    case jetton(URL?)
    case nft(URL?)
  }
  
  public enum TitleType {
    case ton
    case jetton(String)
    case nft
  }
  
  public enum DescriptionType {
    case ton
    case jetton
    case nft(String)
  }
  
  public let image: Image
  public let titleType: TitleType
  public let descriptionType: DescriptionType
  public let wallet: Wallet
  public let recipientAddress: String?
  public let recipientName: String?
  public let amount: String?
  public let amountConverted: LoadableModelItem<String?>
  public let fee: LoadableModelItem<String>
  public let feeConverted: LoadableModelItem<String?>
  public let comment: String?
}
