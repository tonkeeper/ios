import UIKit

public extension UIImage.TKUIKit {
  enum Images {
    public static var tonkeeperLogo72: UIImage {
      .imageWithName("Images/tonkeeper_logo")
    }
    public enum PaymentMethods {
      public static var mastercardVisaCardsLogo: UIImage {
        .imageWithName("Images/PaymentMethods/mastercardVisaCards-logo")
      }
      public static var mirCardLogo: UIImage {
        .imageWithName("Images/PaymentMethods/mirCard-logo")
      }
      public static var cryptocyrrencyLogo: UIImage {
        .imageWithName("Images/PaymentMethods/cryptocurrencies-logo")
      }
      public static var applePayCardLogo: UIImage {
        .imageWithName("Images/PaymentMethods/applePayCard-logo")
      }
    }
    public enum Pools {
      public static var tonstakers: UIImage {
        .imageWithName("Images/Pools/Tonstakers")
      }
      public static var bemo: UIImage {
        .imageWithName("Images/Pools/Bemo")
      }
      public static var tonWhales: UIImage {
        .imageWithName("Images/Pools/TONWhales")
      }
      public static var tonNominators: UIImage {
        .imageWithName("Images/Pools/TONNominators")
      }
      public static var tonkeeperPool1: UIImage {
        .imageWithName("Images/Pools/TonkeeperPool1")
      }
    }
  }
}
