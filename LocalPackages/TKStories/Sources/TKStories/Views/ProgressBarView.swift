import UIKit

final class ProgressBarView: UIView {
  
  var barsCount = 4 {
    didSet {
      setupBars()
    }
  }
  var animationDuration: TimeInterval = 0 {
    didSet {
      barViews.forEach { $0.animationDuration = animationDuration }
    }
  }
  
  private let stackView = UIStackView()
  private var barViews = [PageBarView]()
  
  private var onAppear: (() -> Void)?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func pause() {
    barViews.forEach { $0.pause() }
  }
  
  func resume() {
    barViews.forEach { $0.resume() }
  }
  
  func setActivePage(index: Int) {
    let activeIndex = min(max(index, 0), barsCount - 1)
    barViews.enumerated().forEach { index, view in
      if index < activeIndex {
        view.progress = 1
      } else if index == activeIndex {
        view.setProgress(1, animated: true)
      } else {
        view.progress = 0
      }
    }
  }
  
  private func setup() {
    stackView.spacing = .barSpace
    stackView.distribution = .fillEqually
    addSubview(stackView)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(CGFloat.padding)
    }
    
    setupBars()
  }
  
  private func setupBars() {
    self.barViews.forEach { $0.removeFromSuperview() }
    var barViews = [PageBarView]()
    for _ in (0..<barsCount) {
      let barView = PageBarView()
      barView.animationDuration = animationDuration
      barViews.append(barView)
      stackView.addArrangedSubview(barView)
    }
    self.barViews = barViews
  }
}

private extension CGFloat {
  static let barSpace: CGFloat = 4
  static let padding: CGFloat = 16
}
