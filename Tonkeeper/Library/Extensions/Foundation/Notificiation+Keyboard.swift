//
//  Notificiation+Keyboard.swift
//  Tonkeeper
//
//  Created by Grigory on 1.6.23..
//

import UIKit

extension Notification {
    var keyboardSize: CGSize? {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size
    }

    var keyboardAnimationDuration: Double? {
        return userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
    }

    var keyboardAnimationCurve: UIView.AnimationCurve? {
        guard let curveUInt = (userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?
            .intValue else {
                return nil
        }

        return UIView.AnimationCurve(rawValue: curveUInt)
    }
}
