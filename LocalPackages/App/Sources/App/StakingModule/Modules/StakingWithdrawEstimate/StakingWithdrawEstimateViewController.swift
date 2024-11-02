import UIKit
import TKUIKit
import KeeperCore
import BigInt

final class StakingWithdrawEstimateViewController: UIViewController {

  private let dateComponentsFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    return formatter
  }()
  
  private let containerView = UIView()
  private let label = UILabel()
  
  private var updateTimer: DispatchSourceTimer?
  
  private let wallet: Wallet
  private let stakingPoolInfo: StackingPoolInfo
  
  init(wallet: Wallet,
       stakingPoolInfo: StackingPoolInfo) {
    self.wallet = wallet
    self.stakingPoolInfo = stakingPoolInfo
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    stopUpdateTimer()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    containerView.layer.cornerRadius = 16
    containerView.layer.cornerCurve = .continuous
    containerView.layer.masksToBounds = true
    containerView.backgroundColor = .Background.content
    
    label.numberOfLines = 0
    
    view.addSubview(containerView)
    containerView.addSubview(label)
    
    containerView.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }
    
    label.snp.makeConstraints { make in
      make.edges.equalTo(containerView).inset(16)
    }
    
    startUpdateTimer()
  }
  
  func startUpdateTimer() {
    let queue = DispatchQueue(label: "StakingWithdrawEstimateViewControllerTimerQueue", qos: .background)
    let timer: DispatchSourceTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
    timer.schedule(deadline: .now(), repeating: 1, leeway: .milliseconds(100))
    timer.resume()
    timer.setEventHandler(handler: { [weak self] in
      self?.updateLabel()
    })
    self.updateTimer = timer
  }
  
  func stopUpdateTimer() {
    self.updateTimer?.cancel()
    self.updateTimer = nil
  }
  
  func updateLabel() {
    guard let cycleEnd = formatCycleEnd(timestamp: stakingPoolInfo.cycleEnd) else {
      label.attributedText = nil
      return
    }
    let string = "Unstake request will be processed after the end of the validation cycle in \(cycleEnd)".withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    DispatchQueue.main.async {
      self.label.attributedText = string
    }
  }
  
  func formatCycleEnd(timestamp: TimeInterval) -> String? {
    let estimateDate = Date(timeIntervalSince1970: timestamp)
    let components = Calendar.current.dateComponents(
      [.hour, .minute, .second], from: Date(),
      to: estimateDate
    )
    return dateComponentsFormatter.string(from: components)
  }
  
  func configureWith(stackingPoolInfo: StackingPoolInfo,
                     tonAmount: BigUInt,
                     isMostProfitable: Bool) {}
}
