public protocol AnalyticsService {
    func logEvent(name: String, args: [String: Any])
}
