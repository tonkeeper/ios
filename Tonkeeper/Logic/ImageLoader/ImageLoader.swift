//
//  ImageLoader.swift
//  Tonkeeper
//
//  Created by Grigory on 3.7.23..
//

import Foundation
import UIKit
import Nuke
import NukeExtensions

protocol ImageLoader: AnyObject {
  func loadImage(imageURL: URL?, imageView: UIImageView, size: CGSize?)
  func prefetchImages(imageURLs: [URL])
  func stopPrefetchImages(imageURLs: [URL])
}

final class NukeImageLoader: ImageLoader {
  let prefetcher = ImagePrefetcher()
  
  func loadImage(imageURL: URL?,
                 imageView: UIImageView,
                 size: CGSize?) {
    
    var processors = [any ImageProcessing]()
    if let size = size {
      processors.append(ImageProcessors.Resize(size: size, upscale: true))
    }
    
    let request = ImageRequest(url: imageURL,
                               processors: processors, userInfo: [.scaleKey: UIScreen.main.scale])
    Task {
      await NukeExtensions.loadImage(with: request, into: imageView)
    }
  }
  
  func prefetchImages(imageURLs: [URL]) {
    prefetcher.startPrefetching(with: imageURLs)
  }
  
  func stopPrefetchImages(imageURLs: [URL]) {
    prefetcher.stopPrefetching(with: imageURLs)
  }
}
