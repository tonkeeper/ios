import Foundation

struct PasscodeInputAssembly {
    private init() {}
    static func module(title: String, reason: String? = nil, lockoutUntil: Date? = nil)
        -> (viewController: PasscodeInputViewController, output: PasscodeInputModuleOutput, input: PasscodeInputModuleInput)
    {
        let viewModel = PasscodeInputViewModelImplementation(title: title, reason: reason, initialLockoutUntil: lockoutUntil)
        let viewController = PasscodeInputViewController(viewModel: viewModel)
        return (viewController, viewModel, viewModel)
    }
}
