//
//  UploadMDFilesUtil.swift
//  LabCam
//
//  Created by ysq on 2021/2/2.
//


import Foundation
import YTKKeyValueStore
import MBProgressHUD
import Alamofire

class UploadMDFilesUtil {
    private let api = LCApi()
    private let db = DatabaseUtil()
    private var uploadQueue: Set<String> = []
    static let uploadNotFoundNotiName = "uploadMDFileNotFoundNotiName"
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(UploadMDFilesUtil.networkChange(noti:)), name: NSNotification.Name("NetworkChange"), object: nil)
    }
    @objc func networkChange(noti: Notification) {
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
        if (status == .notReachable || status == .unknown) {
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
        let filesInfo = self.db.getMDFilesInfo()
        if (filesInfo.count > 0) {
            for fileInfo in filesInfo {
                self.uploadFile(info: fileInfo)
            }
        }
    }
    private func uploadFile(info: YTKKeyValueItem) {
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
        self.api.getUploadLinkWithRepoInfo(repoId: repoId!, p: p!) { [weak self] (url) in
            guard let weakSelf = self else {
                return
            }
            print(url)
            let rootPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
            let filePath = "\(rootPath)/\(id)"
            do {
                let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
                weakSelf.api.uploadFile(uploadLink: url, parent_dir: p!, fileData: fileData, fileName: id) {
                    weakSelf.db.saveMDFileInfo(filePath: filePath, fileName: id, isUploaded: true, t_repoInfo: [
                        "repoId": repoId!,
                        "p": p!
                    ])
                    weakSelf.removeUploadQueueWithId(id: id)
                } failure: {
                    weakSelf.removeUploadQueueWithId(id: id)
                }
            } catch {
                weakSelf.removeUploadQueueWithId(id: id)
            }
        } failure: { [weak self] (notFound) in
            guard let weakSelf = self else {
                return
            }
            if (notFound) {
                weakSelf.db.removeRepoInfo()
                let rootPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
                let filePath = "\(rootPath)/\(id)"
                weakSelf.db.saveMDFileInfo(filePath: filePath, fileName: id, isUploaded: false, t_repoInfo: nil)
                NotificationCenter.default.post(name: NSNotification.Name(UploadMDFilesUtil.uploadNotFoundNotiName), object: [
                    "id": id
                ])
            }
            weakSelf.removeUploadQueueWithId(id: id)
        }
    }
    private func removeUploadQueueWithId(id: String) {
        self.uploadQueue.remove(id)
    }
}

