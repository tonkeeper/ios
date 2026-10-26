import StoreKit
import TKAppInfo
import TKFeatureFlags
import TKServices
import UIKit

public protocol InAppReviewService {
    func requestReviewManual()
    func trackSuccessfulSend()
}

public final class InAppReviewRepository {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var successfulSendCount: Int {
        get {
            userDefaults.integer(forKey: .inAppReviewSuccessfulSendCountKey)
        }
        set {
            userDefaults.set(newValue, forKey: .inAppReviewSuccessfulSendCountKey)
        }
    }

    var lastReviewedAppVersion: String? {
        get {
            userDefaults.string(forKey: .inAppReviewLastReviewedAppVersionKey)
        }
        set {
            userDefaults.set(newValue, forKey: .inAppReviewLastReviewedAppVersionKey)
        }
    }

    var lastReviewRequestDate: Date? {
        get {
            userDefaults.object(forKey: .inAppReviewLastRequestDateKey) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: .inAppReviewLastRequestDateKey)
        }
    }
}

public final class InAppReviewServiceImplementation {
    private let analyticsProvider: AnalyticsProvider?
    private let featureFlags: TKFeatureFlags
    private let repository: InAppReviewRepository
    private let firstLaunchDate: Date?
    private let appVersion: String

    public init(
        featureFlags: TKFeatureFlags,
        analyticsProvider: AnalyticsProvider? = nil,
        repository: InAppReviewRepository = InAppReviewRepository(),
        firstLaunchDate: Date?,
        appVersion: String
    ) {
        self.featureFlags = featureFlags
        self.analyticsProvider = analyticsProvider
        self.repository = repository
        self.firstLaunchDate = firstLaunchDate
        self.appVersion = appVersion
    }
}

extension InAppReviewServiceImplementation: InAppReviewService {
    public func requestReviewManual() {
        _ = self.requestReview(action: .manual)
    }

    public func trackSuccessfulSend() {
        repository.successfulSendCount += 1

        guard shouldRequestReviewTransactionSent else {
            return
        }

        if self.requestReview(action: .sentTransaction) {
            repository.successfulSendCount = 0
            return
        }
    }
}

private extension InAppReviewServiceImplementation {
    var shouldRequestReviewTransactionSent: Bool {
        guard shouldRequestReviewCommon else {
            return false
        }
        guard repository.successfulSendCount >= Constants.minimumSuccessfulSends else {
            return false
        }
        return true
    }

    var shouldRequestReviewCommon: Bool {
        guard UIApplication.shared.isAppStoreEnvironment else {
            return false
        }
        guard featureFlags[.inAppReviewEnabled] else {
            return false
        }
        guard let firstLaunchDate else {
            return false
        }
        guard !Calendar.current.isDateInToday(firstLaunchDate) else {
            return false
        }
        guard repository.lastReviewedAppVersion != appVersion else {
            return false
        }

        return canRequestReviewByCooldown
    }

    var canRequestReviewByCooldown: Bool {
        guard let lastReviewRequestDate = repository.lastReviewRequestDate else {
            return true
        }
        guard let nextAllowedDate = Calendar.current.date(
            byAdding: .month,
            value: Constants.reviewCooldownInMonths,
            to: lastReviewRequestDate
        ) else {
            return true
        }
        return Date() >= nextAllowedDate
    }

    private func requestReview(action: InappReview.Action) -> Bool {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else {
            return false
        }

        SKStoreReviewController.requestReview(in: scene)

        repository.lastReviewRequestDate = Date()
        repository.lastReviewedAppVersion = appVersion
        analyticsProvider?.log(InappReview(action: action))

        return true
    }
}

private extension String {
    static let inAppReviewSuccessfulSendCountKey = "in_app_review_successful_send_count"
    static let inAppReviewLastReviewedAppVersionKey = "in_app_review_last_reviewed_app_version"
    static let inAppReviewLastRequestDateKey = "in_app_review_last_request_date"
}

private enum Constants {
    static let minimumSuccessfulSends = 3
    static let reviewCooldownInMonths = 6
}
