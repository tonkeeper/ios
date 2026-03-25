import SignRaw

extension SignRawSendAnalyticsPayload.FeePaidIn {
    var redFeePaidIn: String {
        switch self {
        case .ton:
            return "ton"
        case .battery:
            return "battery"
        case .gasless:
            return "gasless"
        }
    }
}
