import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore
import TKScreenKit
import BigInt

final class StakingCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let stakingAmountController: StakingAmountController
    private let stakingOptionsController: StakingOptionsController
    private let wallet: Wallet
    
    var didFinish: (() -> Void)?
    
    init(
        router: NavigationControllerRouter,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        stakingAmountController: StakingAmountController,
        stakingOptionsController: StakingOptionsController,
        wallet: Wallet
    ) {
        self.stakingAmountController = stakingAmountController
        self.stakingOptionsController = stakingOptionsController
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        super.init(router: router)
    }
    
    public override func start() {
        openAmount()
    }
}

private extension StakingCoordinator {
    func openAmount() {
        router.rootViewController.configureDefaultAppearance()
        
        let module = StakingAmountAssembly.module(
            stakingAmountController: stakingAmountController,
            stakingOptionsController: stakingOptionsController
        )
        
        module.view.setupRightCloseButton { [weak self] in
            self?.didFinish?()
        }
        
        module.view.navigationItem.setupButton(with: .TKUIKit.Icons.Size16.informationCircle) {
            
        }
        
        module.output.didTapContinue = { [weak self] stakingModel in
            self?.openConfirmation(stakingModel: stakingModel)
        }
        
        module.output.didSelectOption = { [weak self] pool in
            self?.openStakingOptions(
                selectedPool: pool,
                didSelect: { selectedPool in
                    module.input.selectOption(selectedPool)
                }
            )
        }
        
        router.push(viewController: module.view, animated: false)
    }
    
    func openStakingOptions(selectedPool: PoolImplementation, didSelect: ((PoolImplementation) -> Void)?) {
        let module = StakingOptionsListAssembly.module(
            stakingOptionsController: stakingOptionsController,
            selectedPool: selectedPool
        )
        
        module.view.setupRightCloseButton { [weak self] in
            self?.didFinish?()
        }
        
        module.view.navigationItem.setupBackButton { [weak self] in
            self?.router.pop()
        }
        
        module.output.didSelectStaking = { [weak self] pool in
            self?.openStakingInfo(
                pool: pool,
                didSelect: didSelect
            )
        }
        
        module.output.didSelectOther = { [weak self] pool in
            self?.openStakingPools(
                selectedPool: selectedPool,
                pool: pool,
                didSelect: didSelect
            )
        }
        
        router.push(viewController: module.view)
    }
    
    func openStakingPools(selectedPool: PoolImplementation, pool: PoolImplementation, didSelect: ((PoolImplementation) -> Void)?) {
        let module = StakingPoolsListAssembly.module(selectedPool: selectedPool, pool: pool)
        
        module.view.title = pool.name
        
        module.view.setupRightCloseButton { [weak self] in
            self?.didFinish?()
        }
        
        module.view.navigationItem.setupBackButton { [weak self] in
            self?.router.pop()
        }
        
        module.output.didSelectPool = { [weak self] pool in
            self?.openStakingInfo(pool: pool, didSelect: didSelect)
        }
        
        router.push(viewController: module.view)
    }
    
    func openStakingInfo(pool: PoolImplementation, didSelect: ((PoolImplementation) -> Void)?) {
        let module = StakingInfoAssembly.module(pool: pool)
        
        let title = pool.pools.first?.name ?? pool.name
        module.view.title = title
        
        module.view.setupRightCloseButton { [weak self] in
            self?.didFinish?()
        }
        
        module.view.navigationItem.setupBackButton { [weak self] in
            self?.router.pop()
        }
        
        module.output.didSelectPool = { [weak self] pool in
            didSelect?(pool)
            self?.router.popToRoot()
        }
        
        module.output.didSelectUrl = { [weak self] url in
            guard let self else { return }
            self.openWebView(url: url, fromViewController: self.router.rootViewController)
        }
        
        router.push(viewController: module.view)
    }
    
    func openConfirmation(
        stakingModel: StakingModel
    ) {
        guard let sendItem = stakingModel.sendItem else { return }
        let sendConfirmationController = keeperCoreMainAssembly.sendConfirmationController(
            wallet: stakingModel.wallet,
            recipient: stakingModel.receipent,
            sendItem: sendItem,
            comment: ""
        )
        
        let module = StakingConfirmationAssembly.module(
            stakingModel: stakingModel,
            sendConfirmationController: sendConfirmationController
        )
        
        module.output.didFinish = { [weak self] in
            self?.didFinish?()
        }
        
        module.view.setupRightCloseButton { [weak self] in
            self?.didFinish?()
        }
        
        module.view.navigationItem.setupBackButton { [weak self] in
            self?.router.pop()
        }
        
        router.push(viewController: module.view)
    }
    
    func openWebView(url: URL, fromViewController: UIViewController) {
      let webViewController = TKWebViewController(url: url)
      let navigationController = UINavigationController(rootViewController: webViewController)
      navigationController.modalPresentationStyle = .fullScreen
      navigationController.configureDefaultAppearance()
      fromViewController.present(navigationController, animated: true)
    }
}

