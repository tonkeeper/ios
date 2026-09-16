import UIKit

struct SettingsListAssembly {
    private init() {}
    static func module(configurator: SettingsListConfigurator)
        -> (viewController: UIViewController, viewModel: SettingsListViewModel)
    {
        let viewModel = SettingsListViewModel(configurator: configurator)
        let viewController = SettingsListHostingViewController(viewModel: viewModel)
        return (viewController, viewModel)
    }
}
