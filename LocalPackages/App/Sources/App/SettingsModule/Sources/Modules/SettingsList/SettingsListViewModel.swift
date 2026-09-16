import Foundation

protocol SettingsListConfigurator: AnyObject {
    var title: String { get }
    var didUpdateState: ((SettingsListState) -> Void)? { get set }
    func getInitialState() -> SettingsListState
}

final class SettingsListViewModel: ObservableObject {
    @Published private(set) var title: String
    @Published private(set) var sections: [SettingsListSection] = []

    var didRequestClose: (() -> Void)?
    var didOpenDevMenu: (() -> Void)?

    private let configurator: SettingsListConfigurator
    private var isStarted = false

    init(configurator: SettingsListConfigurator) {
        self.configurator = configurator
        title = configurator.title
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        configurator.didUpdateState = { [weak self] state in
            DispatchQueue.main.async {
                self?.sections = state.sections
            }
        }
        sections = configurator.getInitialState().sections
    }

    func close() {
        didRequestClose?()
    }

    func openDevMenu() {
        didOpenDevMenu?()
    }
}
