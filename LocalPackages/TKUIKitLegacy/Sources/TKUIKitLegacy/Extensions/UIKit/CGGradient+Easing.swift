//
//  CGGradient+Easing.swift
//
//
//  Created by Grigory on 22.9.23..
//

// https://gist.github.com/drinkius/54cd2eb4bfb8769816e205fa5eb4615b

import UIKit

public typealias Easing = (_ t: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat

public struct Cubic {
  public static var easeIn: Easing = { (_t,b,c,d) -> CGFloat in
    let t = _t/d
    return c*t*t*t + b
  }
  
  public static var easeOut: Easing = { (_t,b,c,d) -> CGFloat in
    let t = _t/d-1
    return c*(t*t*t + 1) + b
  }
  
  public static var easeInOut: Easing = { (_t,b,c,d) -> CGFloat in
    var t = _t/(d/2)
    if t < 1 {
      return c/2*t*t*t + b;
    }
    t -= 2
    return c/2*(t*t*t + 2) + b;
  }
}

public extension CGGradient {
  
  class func chartGradient() -> CGGradient {
    var colors = [CGColor]()
    var locations = [CGFloat]()
    
    let between: UIColor = .Legacy.Background.page
    let and: UIColor = .Legacy.Accent.blue
    
    let percents: [CGFloat] = [
      0.1, 0.99, 0.96, 0.91, 0.85, 0.76, 0.66, 0.55, 0.44, 0.33, 0.23, 0.14, 0.08, 0.03, 0.008, 0
    ]
    
    for (index, percent) in percents.enumerated() {
      locations.append(CGFloat(index)/CGFloat(percents.count))
      colors.append(interpolateColor(at: percent * 0.25, between: between, and: and))
    }
    
    return with(colors: colors, locations: locations)
  }
  
  class func with(colors: [UIColor], locations: [CGFloat]) -> CGGradient {
    return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map{$0.cgColor} as CFArray, locations: locations)!
  }
  
  private class func with(colors: [CGColor], locations: [CGFloat]) -> CGGradient {
    return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
  }
  
  class func with(easing: Easing, between: UIColor, and: UIColor) -> CGGradient {
    var colors = [CGColor]()
    var locations = [CGFloat]()
    let samples = 24
    
    for i in 0...24 {
      let tt = CGFloat(i)/CGFloat(samples)
      
      // calculate t based on easing function provided
      let t = easing(tt, 0.0, 1, 1)
      
      locations.append(tt)
      colors.append(interpolateColor(at: t, between: between, and: and))
    }
    return with(colors: colors, locations: locations)
  }
  
  private class func linearBezierCurveFactors(t: CGFloat) -> (CGFloat, CGFloat) {
    return ((1-t),t)
  }
  
  private class func interpolateColor(at percent: CGFloat, between: UIColor, and: UIColor) -> CGColor{
    var r1: CGFloat = 0.0, g1: CGFloat = 0.0, b1: CGFloat = 0.0, a1: CGFloat = 0.0
    var r2: CGFloat = 0.0, g2: CGFloat = 0.0, b2: CGFloat = 0.0, a2: CGFloat = 0.0
    
    if between.cgColor.components?.count == 4 {
      between.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    } else {
      between.getWhite(&r1, alpha: &a1)
      b1 = r1; g1 = r1
    }
    
    if and.cgColor.components?.count == 4 {
      and.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    } else {
      and.getWhite(&r2, alpha: &a2)
      b2 = r2; g2 = r2
    }
    
    let r = bezierCurve(t: percent, p0: r1, p1: r2)
    let g = bezierCurve(t: percent, p0: g1, p1: g2)
    let b = bezierCurve(t: percent, p0: b1, p1: b2)
    let a = bezierCurve(t: percent, p0: a1, p1: a2)
    
    return UIColor(red: r, green: g, blue: b, alpha: a).cgColor
  }

  
  // Linear Bezier Curve, Just a Parameterized Line Equation
  private class func bezierCurve(t: CGFloat, p0: CGFloat, p1: CGFloat) -> CGFloat {
    let factors = linearBezierCurveFactors(t: t)
    return (factors.0*p0) + (factors.1*p1)
  }
}
