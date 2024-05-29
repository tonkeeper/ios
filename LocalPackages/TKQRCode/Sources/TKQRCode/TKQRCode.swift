import Foundation

public enum TKQRCode {
  public static var qrCodeGenerator: TKQRCodeGenerator {
    TKQRCodeGeneratorImplementation()
  }
  
  public static let defaultCharLimit = 256
}
