//
//  ImageLoader.swift
//  Tonkeeper
//
//  Created by Grigory on 3.7.23..
//

import Foundation
import UIKit
import Kingfisher

protocol ImageLoader: AnyObject {
  func loadImage(imageURL: URL?, imageView: UIImageView, size: CGSize?)
  func prefetchImages(imageURLs: [URL])
  func stopPrefetchImages(imageURLs: [URL])
}

final class NukeImageLoader: ImageLoader {
  func loadImage(imageURL: URL?,
                 imageView: UIImageView,
                 size: CGSize?) {

    var options = KingfisherOptionsInfo()
    if let size = size {
      options.append(.processor(DownsamplingImageProcessor(size: size)))
      options.append(.scaleFactor(UIScreen.main.scale))
    }
    
    imageView.kf.setImage(with: imageURL, options: options)
  }
  
  func prefetchImages(imageURLs: [URL]) {
    let prefetcher = ImagePrefetcher(urls: imageURLs)
    prefetcher.start()
  }
  
  func stopPrefetchImages(imageURLs: [URL]) {}
}
