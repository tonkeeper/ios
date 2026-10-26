import Foundation

/// A quote `signature` is a JWT whose payload is the quote itself. Payment frames read that payload
/// before rendering and reject it unless `wallet.address`, `paymentMethod.type`, `source` and
/// `destination` amounts/assets are present and `executable` is true.
public enum MoonPayQuoteSignature {
    public static let fieldsRequiredByPaymentFrames = [
        "signature", "wallet.address", "paymentMethod.type",
        "source.amount", "source.asset", "destination.amount", "destination.asset",
    ]

    public static func payload(of signature: String) -> MoonPayJSONValue? {
        let segments = signature.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2, let data = base64URLDecode(String(segments[1])) else { return nil }
        return try? MoonPayJSONCoding.makeDecoder().decode(MoonPayJSONValue.self, from: data)
    }

    /// Dotted paths from `fieldsRequiredByPaymentFrames` that the payload lacks; empty when a
    /// payment frame would accept the signature's shape (it still checks `executable`).
    public static func missingPaymentFrameFields(in payload: MoonPayJSONValue) -> [String] {
        fieldsRequiredByPaymentFrames.filter { path in
            var value: MoonPayJSONValue? = payload
            for key in path.split(separator: ".") {
                value = value?[String(key)]
            }
            guard let value else { return true }
            if case .null = value { return true }
            return false
        }
    }

    static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }
}
