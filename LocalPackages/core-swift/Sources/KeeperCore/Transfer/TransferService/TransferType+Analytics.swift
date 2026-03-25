extension TransferType {
    var analyticsName: String {
        switch self {
        case .default:
            "default"
        case .battery:
            "battery"
        case .gasless:
            "gasless"
        }
    }
}
