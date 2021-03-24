//
//  UIImageUtil.swift
//  LabCam
//
//  Created by ysq on 2021/2/1.
//

import Foundation
import UIKit

class UIImageUtil {
    class func imageWithColor(color: UIColor, width: CGFloat, height: CGFloat) -> UIImage?
    {
        let rect = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        UIGraphicsBeginImageContext(rect.size)
        let context:CGContext = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor);
        context.fill(rect);
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

extension UIImage {
    func crop43() -> UIImage {
        var newSize:CGSize!
        if (self.size.height >= self.size.width) {
            let w = 3 * self.size.height / 4
            if (w <= self.size.width) {
                newSize = CGSize(width: w, height: self.size.height)
            } else {
                let h = self.size.width * 4 / 3
                newSize = CGSize(width: self.size.width, height: h)
            }
        } else {
            let h = self.size.width * 3 / 4
            if (h <= self.size.height) {
                newSize = CGSize(width: self.size.width, height: h)
            } else {
                let w = 4 * self.size.height / 3
                newSize = CGSize(width: w, height: self.size.height)
            }
        }
        var rect = CGRect.zero
        rect.size.width  = size.width
        rect.size.height = size.height
        rect.origin.x    = (newSize.width - size.width ) / 2.0
        rect.origin.y    = (newSize.height - size.height ) / 2.0
        UIGraphicsBeginImageContext(newSize)
        draw(in: rect)
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaledImage!
    }
}
