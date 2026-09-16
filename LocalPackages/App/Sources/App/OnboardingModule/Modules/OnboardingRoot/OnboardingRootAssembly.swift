import Foundation
import TKCore
import TKUIKit
import UIKit

struct OnboardingRootAssembly {
    private init() {}

    static func module() -> MVVMModule<UIViewController, OnboardingRootModuleOutput, Void> {
        let viewModel = OnboardingRootViewModelImplementation()
        return .init(view: OnboardingRootViewController(viewModel: viewModel), output: viewModel, input: ())
    }
}
