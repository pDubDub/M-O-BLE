//
//  View+Borders.swift
//  M-O BLE
//
//  Extension to allow setting button corners and borders in Interface Builder.
//
//  Created by Patrick Wheeler on 7/13/20.
//  Copyright © 2020 Patrick Wheeler. All rights reserved.
//
//  https://stackoverflow.com/questions/33942483/swift-extension-example
//
//

//import Foundation
import UIKit

extension UIView {

    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }

    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable var borderColor: UIColor? {
        get {
            return UIColor(cgColor: layer.borderColor!)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }
}
