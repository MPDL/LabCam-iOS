//
//  ButtonUtil.swift
//  LabCam
//
//  Created by ysq on 2021/2/3.
//

import Foundation
import UIKit
 
var expandSizeKey = "expandSizeKey"
 
extension UIButton {
    
    open func lzh_expandSize(size:CGFloat) {
        objc_setAssociatedObject(self, &expandSizeKey,size, objc_AssociationPolicy.OBJC_ASSOCIATION_COPY)
    }
    
    private func expandRect() -> CGRect {
        let expandSize = objc_getAssociatedObject(self, &expandSizeKey)
        if (expandSize != nil) {
            return CGRect(x: bounds.origin.x - (expandSize as! CGFloat), y: bounds.origin.y - (expandSize as! CGFloat), width: bounds.size.width + 2*(expandSize as! CGFloat), height: bounds.size.height + 2*(expandSize as! CGFloat))
        }else{
            return bounds;
        }
    }
    
    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let buttonRect =  expandRect()
        if (buttonRect.equalTo(bounds)) {
            return super.point(inside: point, with: event)
        }else{
            return buttonRect.contains(point)
        }
    }
}
