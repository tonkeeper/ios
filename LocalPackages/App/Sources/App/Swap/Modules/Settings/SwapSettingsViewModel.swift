import Foundation

protocol SwapSettingsModuleOutput: AnyObject {
    var didSelectTolerance: ((Int) -> Void)? { get set }
}

protocol SwapSettingsModuleInput: AnyObject {
}

protocol SwapSettingsViewModel: AnyObject {
    var currentTolerance: Int { get }
    func selectTolerance(tolerance: Int)
    
    func didTapSaveButton()
}

final class SwapSettingsViewModelImplementation: SwapSettingsViewModel, SwapSettingsModuleOutput, SwapSettingsModuleInput {
    
    // MARK: - SwapSettingsModuleOutput
    
    var didSelectTolerance: ((Int) -> Void)?
        
    // MARK: - SwapSettingsViewModel
    
    func selectTolerance(tolerance: Int) {
        selectedTolerance = tolerance
    }
    
    func didTapSaveButton() {
        didSelectTolerance?(selectedTolerance)
    }
    
    // MARK: - Init
    
    private var selectedTolerance: Int = 0
    private(set) var currentTolerance: Int
    
    init(currentTolerance: Int) {
        self.currentTolerance = currentTolerance
    }
    
}
