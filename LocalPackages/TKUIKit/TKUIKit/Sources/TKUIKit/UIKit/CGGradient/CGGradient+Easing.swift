import UIKit

protocol EaseFunction {
  func invoke(_ t:CGFloat, _ b:CGFloat, _ c:CGFloat, _ d:CGFloat) -> CGFloat
}

typealias LerpFunction = (_ t:CGFloat, _ b:CGFloat, _ c:CGFloat, _ d:CGFloat) -> CGFloat

public struct Easing : EaseFunction {
  
  private let lerp: LerpFunction
  
  init(_ lerp: @escaping LerpFunction){
    self.lerp = lerp
  }
  
  func invoke(_ t: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
    return lerp(t, b, c, d)
  }
  
  // linear
  public static let easeInLinear    = Easing { (t,b,c,d) -> CGFloat in
    return c*(t/d)+b
  }
  public static let easeOutLinear   = Easing { (t,b,c,d) -> CGFloat in
    return c*(t/d)+b
  }
  public static let easeInOutLinear = Easing { (t,b,c,d) -> CGFloat in
    return c*(t/d)+b
  }
  
  // quad
  public static let easeInQuad   = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d
    return c*t*t + b
  }
  public static let easeOutQuad  = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d
    return -c * t*(t-2) + b
  }
  public static let easeInOutQuad = Easing { (_t,b,c,d) -> CGFloat in
    var t = _t/(d/2)
    if t < 1 {
      return c/2*t*t + b;
    }
    let t1 = t-1
    let t2 = t1-2
    return -c/2 * ((t1)*(t2) - 1) + b;
  }
  
  // cubic
  public static let easeInCubic   = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d
    return c*t*t*t + b
  }
  public static let easeOutCubic   = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d-1
    return c*(t*t*t + 1) + b
  }
  public static let easeInOutCubic = Easing { (_t,b,c,d) -> CGFloat in
    var t = _t/(d/2)
    if t < 1{
      return c/2*t*t*t + b;
    }
    t -= 2
    return c/2*(t*t*t + 2) + b;
  }
  
  // quart
  public static let easeInQuart   = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d
    return c*t*t*t*t + b
  }
  public static let easeOutQuart  = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d-1
    return -c * (t*t*t*t - 1) + b
  }
  public static let easeInOutQuart = Easing { (_t,b,c,d) -> CGFloat in
    var t = _t/(d/2)
    
    if t < 1{
      return c/2*t*t*t*t + b;
    }
    t -= 2
    return -c/2 * (t*t*t*t - 2) + b;
  }
  
  // quint
  public static let easeInQuint     = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d
    return c*t*t*t*t*t + b
  }
  public static let easeOutQuint    = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d-1
    return c*(t*t*t*t*t + 1) + b
  }
  public static let easeInOutQuint  = Easing { (_t,b,c,d) -> CGFloat in
    var t = _t/(d/2)
    if t < 1 {
      return c/2*t*t*t*t*t + b;
    }
    t -= 2
    return c/2*(t*t*t*t*t + 2) + b;
  }
  
  // back
  public static let easeInBack    = Easing { (_t,b,c,d) -> CGFloat in
    let s:CGFloat = 1.70158
    let t = _t/d
    return c*t*t*((s+1)*t - s) + b
  }
  public static let easeOutBack   = Easing { (_t,b,c,d) -> CGFloat in
    let s:CGFloat = 1.70158
    let t = _t/d-1
    return c*(t*t*((s+1)*t + s) + 1) + b
  }
  public static let easeInOutBack = Easing { (_t,b,c,d) -> CGFloat in
    var s:CGFloat = 1.70158
    var t = _t/(d/2)
    if t < 1{
      s *= (1.525)
      return c/2*(t*t*((s+1)*t - s)) + b;
    }
    s *= 1.525
    t -= 2
    return c/2*(t*t*((s+1)*t + s) + 2) + b;
  }
  
  // bounce
  public static let easeInBounce    = Easing { (t,b,c,d) -> CGFloat in
    return c - easeOutBounce.invoke(d-t, b, c, d) + b
  }
  public static let easeOutBounce   = Easing { (_t,b,c,d) -> CGFloat in
    var t = _t/d
    if t < (1/2.75){
      return c*(7.5625*t*t) + b;
    } else if t < (2/2.75) {
      t -= 1.5/2.75
      return c*(7.5625*t*t + 0.75) + b;
    } else if t < (2.5/2.75) {
      t -= 2.25/2.75
      return c*(7.5625*t*t + 0.9375) + b;
    } else {
      t -= 2.625/2.75
      return c*(7.5625*t*t + 0.984375) + b;
    }
  }
  public static let easeInOutBounce = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t
    if t < d/2{
      return easeInBounce.invoke(t*2, 0, c, d) * 0.5 + b
    }
    return easeOutBounce.invoke (t*2-d, 0, c, d) * 0.5 + c*0.5 + b
  }
  
  
  // circ
  public static let easeInCirc    = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d
    return -c * (sqrt(1 - t*t) - 1) + b
  }
  public static let easeOutCirc   = Easing { (_t,b,c,d) -> CGFloat in
    let t = _t/d-1
    return c * sqrt(1 - t*t) + b
  }
  public static let easeInOutCirc = Easing { (_t,b,c,d) -> CGFloat in
    var t = _t/(d/2)
    if t < 1{
      return -c/2 * (sqrt(1 - t*t) - 1) + b;
    }
    t -= 2
    return c/2 * (sqrt(1 - t*t) + 1) + b;
  }
  
  // elastic
  public static var easeInElastic    = Easing { (_t,b,c,d) -> CGFloat in
    var t = _t
    
    if t==0{ return b }
    t/=d
    if t==1{ return b+c }
    
    let p = d * 0.3
    let a = c
    let s = p/4
    
    t -= 1
    return -(a*pow(2,10*t) * sin( (t*d-s)*(2*CGFloat.pi)/p )) + b;
  }
  public static let easeOutElastic   = Easing { (_t,b,c,d) -> CGFloat in
    var t = _t
    
    if t==0{ return b }
    t/=d
    if t==1{ return b+c}
    
    let p = d * 0.3
    let a = c
    let s = p/4
    
    return (a*pow(2,-10*t) * sin( (t*d-s)*(2*CGFloat.pi)/p ) + c + b);
  }
  public static let easeInOutElastic = Easing { (_t,b,c,d) -> CGFloat in
    var t = _t
    if t==0{ return b}
    
    t = t/(d/2)
    if t==2{ return b+c }
    
    let p = d * (0.3*1.5)
    let a = c
    let s = p/4
    
    if t < 1 {
      t -= 1
      return -0.5*(a*pow(2,10*t) * sin((t*d-s)*(2*CGFloat.pi)/p )) + b;
    }
    t -= 1
    return a*pow(2,-10*t) * sin( (t*d-s)*(2*CGFloat.pi)/p )*0.5 + c + b;
  }
  
  // expo
  public static let easeInExpo    = Easing { (_t,b,c,d) -> CGFloat in
    return (_t==0) ? b : c * pow(2, 10 * (_t/d - 1)) + b
  }
  public static let easeOutExpo   = Easing { (_t,b,c,d) -> CGFloat in
    return (_t==d) ? b+c : c * (-pow(2, -10 * _t/d) + 1) + b
  }
  public static let easeInOutExpo = Easing { (_t,b,c,d) -> CGFloat in
    if _t==0{ return b }
    if _t==d{ return b+c}
    
    var t = _t/(d/2)
    
    if t < 1{
      return c/2 * pow(2, 10 * (_t - 1)) + b;
    }
    let t1 = t-1
    return c/2 * (-pow(2, -10 * t1) + 2) + b;
  }
  
  // sine
  public static let easeInSine    = Easing { (_t,b,c,d) -> CGFloat in
    return -c * cos(_t/d * (CGFloat.pi/2)) + c + b
  }
  public static let easeOutSine   = Easing { (_t,b,c,d) -> CGFloat in
    return c * sin(_t/d * (CGFloat.pi/2)) + b
  }
  public static let easeInOutSine = Easing { (_t,b,c,d) -> CGFloat in
    return -c/2 * (cos(CGFloat.pi*_t/d) - 1) + b
  }
}

extension CGGradient{
  
  class func with(_ colors:[UIColor],_ locations:[CGFloat]) -> CGGradient{
    return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map{$0.cgColor} as CFArray, locations: locations)!
  }
  
  private class func with(_ colors:[CGColor],_ locations:[CGFloat]) -> CGGradient{
    return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
  }
  
  public class func with(easing: Easing, from c1: UIColor, to c2: UIColor) -> CGGradient{
    var colors    = [CGColor]()
    var locations = [CGFloat]()
    let samples = 24
    
    func interpolateColor(at percent:CGFloat) -> CGColor {
      var r1:CGFloat = 0.0, g1:CGFloat = 0.0, b1:CGFloat = 0.0, a1:CGFloat = 0.0
      var r2:CGFloat = 0.0, g2:CGFloat = 0.0, b2:CGFloat = 0.0, a2:CGFloat = 0.0
      
      if 4 == c1.cgColor.components?.count{
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
      }else{
        c1.getWhite(&r1, alpha: &a1)
        b1 = r1; g1 = r1
      }
      
      if 4 == c2.cgColor.components?.count{
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
      }else{
        c2.getWhite(&r2, alpha: &a2)
        b2 = r2; g2 = r2
      }
      
      let r = BezierCurve(t: percent, p0: r1, p1: r2)
      let g = BezierCurve(t: percent, p0: g1, p1: g2)
      let b = BezierCurve(t: percent, p0: b1, p1: b2)
      let a = BezierCurve(t: percent, p0: a1, p1: a2)
      
      return UIColor(red: r, green: g, blue: b, alpha: a).cgColor
    }
    
    
    for i in 0...samples {
      let tt = CGFloat(i)/CGFloat(samples)
      
      // calculate t based on easing function provided
      let t = easing.invoke(tt, 0.0, 1, 1)
      
      locations.append(tt)
      colors.append(interpolateColor(at: t))
    }
    return with(colors, locations)
  }
}

fileprivate func BezierCurve(t:CGFloat, p0:CGFloat, p1:CGFloat) -> CGFloat{
  return (1.0 - t) * p0 + t * p1;
}

