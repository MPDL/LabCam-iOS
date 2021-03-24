//
//  ReachabilityManager.swift
//  LabCam
//
//  Created by ysq on 2021/2/2.
//

import Foundation
import Alamofire

class ReachabilityManager {
    static let shared = ReachabilityManager()
    public let reachabilityManager: Alamofire.NetworkReachabilityManager? = Alamofire.NetworkReachabilityManager(host: "keeper.mpdl.mpg.de")
    public func startNetworkReachabilityObserver() {
        self.reachabilityManager?.startListening { (status) in
            switch status {
            case .notReachable:
                NotificationCenter.default.post(name: NSNotification.Name.init("NetworkChange"), object: [
                    "status": status,
                ])
            case .reachable(_):
                NotificationCenter.default.post(name: NSNotification.Name.init("NetworkChange"), object: [
                    "status": status,
                ])
            case .unknown:
                NotificationCenter.default.post(name: NSNotification.Name.init("NetworkChange"), object: [
                    "status": status,
                ])
            }
        }
    }
}
