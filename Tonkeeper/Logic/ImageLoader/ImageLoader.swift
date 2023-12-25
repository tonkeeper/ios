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
  func loadImage(imageURL: URL?, imageView: UIImageView, size: CGSize?, cornerRadius: CGFloat?)
  func prefetchImages(imageURLs: [URL])
  func stopPrefetchImages(imageURLs: [URL])
}

extension ImageLoader {
  func loadImage(imageURL: URL?, imageView: UIImageView, size: CGSize?) {
    self.loadImage(imageURL: imageURL, imageView: imageView, size: size, cornerRadius: nil)
  }
}

final class NukeImageLoader: ImageLoader {
  func loadImage(imageURL: URL?,
                 imageView: UIImageView,
                 size: CGSize?,
                 cornerRadius: CGFloat? = nil) {

    var options = KingfisherOptionsInfo()
    var processor: ImageProcessor = DefaultImageProcessor.default
    
    options.append(.keepCurrentImageWhileLoading)
    options.append(.loadDiskFileSynchronously)
    options.append(.memoryCacheExpiration(.expired))
    
    if let size = size {
      processor = processor |> DownsamplingImageProcessor(size: size)
      options.append(.scaleFactor(UIScreen.main.scale))
    }
    if let cornerRadius = cornerRadius {
      processor = processor |> RoundCornerImageProcessor(cornerRadius: cornerRadius)
    }

    options.append(.processor(processor))
    
    imageView.kf.setImage(with: imageURL, options: options)
  }
  
  func prefetchImages(imageURLs: [URL]) {
    let prefetcher = ImagePrefetcher(urls: imageURLs)
    prefetcher.start()
  }
  
  func stopPrefetchImages(imageURLs: [URL]) {}
}
