import Foundation
import TKCore

protocol TooltipDataRepository {
    var firstLaunchDate: Date? { get }
}

final class TooltipDataRepositoryImplementation {
    private let appSettings: AppSettings
    private let userDefaults: UserDefaults
    private let overridesRepository: TooltipDataOverridesRepository

    init(
        appSettings: AppSettings,
        userDefaults: UserDefaults = .standard,
        overridesRepository: TooltipDataOverridesRepository
    ) {
        self.appSettings = appSettings
        self.userDefaults = userDefaults
        self.overridesRepository = overridesRepository
    }
}

extension TooltipDataRepositoryImplementation: TooltipDataRepository {
    var firstLaunchDate: Date? {
        overridesRepository.firstLaunchDate ?? appSettings.firstLaunchDate
    }
}
