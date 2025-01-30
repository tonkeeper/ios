import UIKit
import AVKit

final class NFTDetailsPlayerView: UIView {
  private var queuePlayer: AVQueuePlayer?
  private var playerLooper: AVPlayerLooper?
  
  private var didEnterBackgroundToken: NSObjectProtocol?
  private var willEnterForegroundToken: NSObjectProtocol?
  
  override class var layerClass: AnyClass {
    AVPlayerLayer.self
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    didEnterBackgroundToken = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main) { [weak self] _ in
        self?.queuePlayer?.pause()
      }
    willEnterForegroundToken = NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: .main) { [weak self] _ in
        self?.queuePlayer?.play()
      }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func play(url: URL) {
    let playerItem = AVPlayerItem(url: url)
    
    let queuePlayer = AVQueuePlayer(playerItem: playerItem)
    (layer as? AVPlayerLayer)?.player = queuePlayer
    
    let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
    
    self.queuePlayer = queuePlayer
    self.playerLooper = playerLooper
    
    self.queuePlayer?.play()
  }
}
