import TKUIKit

extension QrCodeErrorCorrectionLevel {
    var ciInputValue: String {
        switch self {
        case .automatic:
            "M"
        case .low:
            "L"
        case .medium:
            "M"
        case .quartile:
            "Q"
        case .high:
            "H"
        }
    }
}
