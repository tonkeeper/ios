import KeeperCore
import TKCore

enum ScannerAnalytics {
    case scanEvents(openUtm: UtmParameters)
    case none
}

/// Accessed only on the main queue. One instance per scanner open: a read code is reported once, whichever
/// way it ends; a gallery pick without a code has nothing to dedupe on and is reported every time.
final class ScanAnalyticsSession {
    private let analyticsProvider: AnalyticsProvider
    private let openUtm: UtmParameters
    private var didLogOpen = false
    private var reportedCodes = Set<String>()

    init(analyticsProvider: AnalyticsProvider, openUtm: UtmParameters) {
        self.analyticsProvider = analyticsProvider
        self.openUtm = openUtm
    }

    func logOpen() {
        guard !didLogOpen else { return }
        didLogOpen = true
        analyticsProvider.log(ScanOpen(), utm: openUtm)
    }

    func logSuccess(code: String, input: ScanInput) {
        guard reportedCodes.insert(code).inserted else { return }
        analyticsProvider.log(ScanSuccess(input: input), utm: UtmParameters(link: code))
    }

    func logError(code: String, input: ScanInput, rejection: ScanRejection) {
        guard reportedCodes.insert(code).inserted else { return }
        analyticsProvider.log(ScanError(input: input, errorType: rejection.errorType))
    }

    func logNoCode() {
        analyticsProvider.log(ScanError(input: .gallery, errorType: .noCode))
    }
}

private extension ScanRejection {
    var errorType: ScanError.ErrorType {
        switch self {
        case .invalidLink:
            .invalidLink
        case .unsupportedHere:
            .unsupportedHere
        }
    }
}

/// A code the scanner parsed. The consumer that opens it reports the outcome: `accept()` once the link is
/// opened, `rejectUnsupported()` when this scanner does not take that kind of link.
struct ScannedDeeplink {
    let deeplink: Deeplink
    let utm: UtmParameters
    let input: ScanInput
    private let code: String
    private let session: ScanAnalyticsSession?

    init(deeplink: Deeplink, code: String, input: ScanInput, session: ScanAnalyticsSession?) {
        self.deeplink = deeplink
        self.code = code
        self.input = input
        self.session = session
        utm = UtmParameters(link: code)
    }

    func accept() {
        session?.logSuccess(code: code, input: input)
    }

    func rejectUnsupported() {
        session?.logError(code: code, input: input, rejection: .unsupportedHere)
    }
}
