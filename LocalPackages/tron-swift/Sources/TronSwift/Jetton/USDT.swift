import Foundation

public enum USDT {
    public static let address = try! Address(address: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t")
    public static let fractionDigits: Int = 6
    public static let symbol = "USD₮"
    public static let name = "USD₮ TRC20"
    public static let imageURL = URL(string: "https://tether.to/images/logoCircle.png")
    public static let tag = "TRC20"
}
