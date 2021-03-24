//
//  UploadImagesUtil.swift
//  LabCam
//
//  Created by ysq on 2021/2/2.
//

import Foundation
import YTKKeyValueStore
import MBProgressHUD
import Alamofire

class UploadImagesUtil {
    private let api = LCApi()
    private let db = DatabaseUtil()
    private var uploadQueue: Set<String> = []
    static let uploadFailureNotiName = "uploadFailureNotiName"
    static let uploadSuccessNotiName = "uploadSuccessNotiName"
    static let uploadNotFoundNotiName = "uploadImageNotFoundNotiName"
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(UploadImagesUtil.networkChange(noti:)), name: NSNotification.Name("NetworkChange"), object: nil)
    }

    @objc func networkChange(noti: Notification) {
        guard let obj = noti.object as? Dictionary<String, Any> else {
            return
        }
        self.startUpload()
    }
    open func startUpload() {
        if (!self.db.userIsLogined()) {
            return
        }
        let userOnlyWifi = self.db.userNetworkIsOnlyWifi()
        guard let status = ReachabilityManager.shared.reachabilityManager?.status else {
            return
        }
        if (status == .notReachable) {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: DispatchTime.now() + 5) { [weak self] () in
                DispatchQueue.main.async {
                    self?.startUpload()
                }
            }
            return
        }
        if (userOnlyWifi && status == .reachable(.cellular)) {
            return
        }
        let imagesInfo = self.db.getImagesInfo()
        if (imagesInfo.count > 0) {
            for imageInfo in imagesInfo {
                self.uploadImage(info: imageInfo)
            }
        }
    }
    private func uploadImage(info: YTKKeyValueItem) {
        let id = info.itemId!
        let item = info.itemObject as! Dictionary<String, Any>
        var repoId = item["repoId"] as? String
        var p = item["p"] as? String
        if (repoId == nil || p == nil) {
            let currentRepoInfo = self.db.getRepoInfo()
            if (currentRepoInfo != nil) {
                repoId = self.db.getRepoInfo()!["repoId"]!
                p = self.db.getRepoInfo()!["p"]!
            } else {
                return
            }
        }
        let isUploaded = item["isUploaded"] as? Bool
        if (isUploaded != nil && isUploaded!) {
            return
        }
        if (self.uploadQueue.contains(id)) {
            return
        }
        self.uploadQueue.insert(id)
        self.api.getUploadLinkWithRepoInfo(repoId: repoId!, p:  p!) { [weak self] (url) in
            guard let weakSelf = self else {
                return
            }
            let rootPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
            let imagePath = "\(rootPath)/\(id)"
            do {
                let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
                weakSelf.api.uploadImage(uploadLink: url, parent_dir: p!, imageData: imageData, imageName: id) {
                    // 更新为已上传
                    weakSelf.db.saveImageInfo(imagePath: imagePath, imageName: id, isUploaded: true, t_repoInfo: [
                        "repoId": repoId!,
                        "p": p!
                    ])
                    weakSelf.removeUploadQueueWithId(id: id)
                    weakSelf.notiUploadSuccess()
                } failure: {
                    weakSelf.removeUploadQueueWithId(id: id)
                    weakSelf.reUpload()
                }
            } catch {
                print("error")
                weakSelf.removeUploadQueueWithId(id: id)
                weakSelf.reUpload()
            }
        } failure: { [weak self] (notFound) in
            print("error")
            NotificationCenter.default.post(name: NSNotification.Name(UploadImagesUtil.uploadFailureNotiName), object: [
                "id": id
            ])
            guard let weakSelf = self else {
                return
            }
            if (notFound) {
                weakSelf.db.removeRepoInfo()
                let rootPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
                let imagePath = "\(rootPath)/\(id)"
                weakSelf.db.saveImageInfo(imagePath: imagePath, imageName: id, isUploaded: false, t_repoInfo: nil)
                NotificationCenter.default.post(name: NSNotification.Name(UploadImagesUtil.uploadNotFoundNotiName), object: [
                    "id": id
                ])
            } else {
                weakSelf.reUpload()
            }
            weakSelf.removeUploadQueueWithId(id: id)
        }
    }
    private func reUpload() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: DispatchTime.now() + 10) { [weak self] () in
            DispatchQueue.main.async {
                self?.startUpload()
            }
        }
    }
    private func removeUploadQueueWithId(id: String) {
        self.uploadQueue.remove(id)
    }
    private func notiUploadSuccess() {
        NotificationCenter.default.post(name: NSNotification.Name(UploadImagesUtil.uploadSuccessNotiName), object: nil)
        if UIApplication.shared.applicationState == .background {
//            let content = UNMutableNotificationContent()
//            content.title = "LabCam"
//            content.body = "Your photos have been uploaded successfully."
//            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
//            let requestIdentifier = "com.labcam.notification"
//            let request = UNNotificationRequest(identifier: requestIdentifier,
//                                                content: content, trigger: trigger)
//            UNUserNotificationCenter.current().add(request) { error in
//            }
        }
    }
}

