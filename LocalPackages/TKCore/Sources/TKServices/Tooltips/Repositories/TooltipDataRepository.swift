import Foundation
import TKFeatureFlags

public protocol TooltipDataRepository {
    var firstLaunchDate: Date? { get }
}

public final class TooltipDataRepositoryImplementation {
    private let appSettings: AppSettings
    private let overridesRepository: TooltipDataOverridesRepository

    public init(
        appSettings: AppSettings,
        overridesRepository: TooltipDataOverridesRepository
    ) {
        self.appSettings = appSettings
        self.overridesRepository = overridesRepository
    }
}

extension TooltipDataRepositoryImplementation: TooltipDataRepository {
    public var firstLaunchDate: Date? {
        overridesRepository.firstLaunchDate ?? appSettings.firstLaunchDate
    }
}
