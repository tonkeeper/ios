import Foundation

public struct FormattersConstants {
  public static let groupSeparator: String = Locale.current.groupingSeparator ?? " "
  public static let fractionalSeparator: String = Locale.current.decimalSeparator ?? "."
}
