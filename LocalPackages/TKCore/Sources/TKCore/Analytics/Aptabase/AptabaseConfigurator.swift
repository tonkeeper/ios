import Aptabase
import Foundation

public final class AptabaseConfigurator {
    public static let configurator = AptabaseConfigurator()

    private init() {}

    public func configure(
        sendStatsImmediately: Bool?
    ) {
        let endpoint = InfoProvider.aptabaseEndpoint()
        let initOptions: InitOptions
        if let sendStatsImmediately {
            initOptions = InitOptions(
                host: endpoint,
                trackingMode: sendStatsImmediately ? .asDebug : .asRelease
            )
        } else {
            initOptions = InitOptions(
                host: endpoint
            )
        }
        Aptabase.shared.initialize(
            appKey: InfoProvider.aptabaseKey()!,
            with: initOptions
        )
    }
}

public class AptabaseService: AnalyticsService {
    public init() {}

    public func logEvent(name: String, args: [String: Any]) {
        Aptabase.shared.trackEvent(name, with: args)
    }
}
