//
//  DatabaseUtil.swift
//  LabCam
//
//  Created by ysq on 2021/2/2.
//

import Foundation
import YTKKeyValueStore

class DatabaseUtil {
    let store: YTKKeyValueStore!
    let mainUrlTable = "MainUrlTable"
    let mainUrlID = "mainUrl"
    let userInfoTable = "UserInfoTable"
    let userTokenID = "userToken"
    let repoInfoTable = "UserRepoInfoTable"
    let repoInfoID = "repoInfo"
    let imageInfoTable = "ImageInfoTable"
    let mdFileInfoTable = "MDFileInfoTable"
    let networkStatuTable = "NetworkStatuTable"
    let networkStatuID = "networkStatu"
    init() {
        self.store = YTKKeyValueStore(dbWithName: "labcam-db.db")
        self.store.createTable(withName: self.userInfoTable)
        self.store.createTable(withName: self.mainUrlTable)
        self.store.createTable(withName: self.repoInfoTable)
        self.store.createTable(withName: self.imageInfoTable)
        self.store.createTable(withName: self.networkStatuTable)
        self.store.createTable(withName: self.mdFileInfoTable)
    }
    // MARK: - remove all data
    open func removeAllData() {
        self.store.clearTable(self.userInfoTable)
        self.store.clearTable(self.repoInfoTable)
        self.store.clearTable(self.imageInfoTable)
        self.store.clearTable(self.networkStatuTable)
        self.store.clearTable(self.mdFileInfoTable)
    }
    // MARK: - save user network types
    open func saveUserNetworkIsOnlyWifi(onlyWifi: Bool) {
        self.store.put([
            "onlyWifi": onlyWifi
        ], withId: self.networkStatuID, intoTable: self.networkStatuTable)
    }
    open func userNetworkIsOnlyWifi() -> Bool {
        if let r = self.store.getObjectById(self.networkStatuID, fromTable: self.networkStatuTable) as? Dictionary<String, Any> {
            if let onlyWifi = r["onlyWifi"] as? Bool {
                return onlyWifi
            }
        }
        return true
    }
    // MARK: - Main Url
    open func saveMainUrl(url: String!) {
        self.store.put(url, withId: self.mainUrlID, intoTable: self.mainUrlTable)
    }
    open func getMainUrl() -> String! {
        return self.store.getStringById(self.mainUrlID, fromTable: self.mainUrlTable) ?? ""
    }
    // MARK: - user info
    open func saveUserToken(token: String!) {
        self.store.put(token, withId: self.userTokenID, intoTable: self.userInfoTable)
    }
    open func getUserToken() -> String? {
        let r = self.store.getStringById(self.userTokenID, fromTable: self.userInfoTable)
        return r
    }
    open func userIsLogined() -> Bool {
        let token = self.getUserToken()
        if (token == nil || token! == "" ) {
            return false
        }
        return true
    }
    open func removeUserToken() {
        self.store.deleteObject(byId: self.userTokenID, fromTable: self.userInfoTable)
    }
    // MARK: - repo info
    open func removeRepoInfo() {
        self.store.deleteObject(byId: self.repoInfoID, fromTable: self.repoInfoTable)
    }
    open func saveRepoInfo(repoId: String, p: String, mainRepoName: String) {
        self.store.put([
            "repoId": repoId,
            "mainRepoName": mainRepoName,
            "p": p
        ], withId: self.repoInfoID, intoTable: self.repoInfoTable)
    }
    open func getRepoInfo() -> Dictionary<String, String>? {
        let r = self.store.getObjectById(self.repoInfoID, fromTable: self.repoInfoTable) as? Dictionary<String, String>
        return r
    }
    // MARK: - save image info
    open func saveImageInfo(imagePath: String, imageName: String, isUploaded: Bool, t_repoInfo: Dictionary<String, String>? = nil) {
        let repoInfo = self.getRepoInfo()
        if (t_repoInfo == nil) {
            if (repoInfo == nil) {
                // 如果都为nil 待更新
                self.store.put([
                    "imagePath": imagePath,
                    "isUploaded": isUploaded
                ], withId: imageName, intoTable: self.imageInfoTable)
                return
            }
        }
        self.store.put([
            "imagePath": imagePath,
            "isUploaded": isUploaded,
            "repoId": t_repoInfo != nil ? t_repoInfo!["repoId"]! : repoInfo!["repoId"]! ,
            "p": t_repoInfo != nil ? t_repoInfo!["p"]! : repoInfo!["p"]!
        ], withId: imageName, intoTable: self.imageInfoTable)
    }
    open func getImagesInfo() -> Array<YTKKeyValueItem> {
        let r = self.store.getAllItems(fromTable: self.imageInfoTable) as? [YTKKeyValueItem] ?? []
        return r
    }
    open func getCurrentRepoImagesInfo() -> Array<YTKKeyValueItem> {
        let imagesInfo = self.getImagesInfo()
        var result: Array<YTKKeyValueItem> = imagesInfo.filter { (imageInfo) -> Bool in
            let item = imageInfo.itemObject as! Dictionary<String, Any>
            let isUploaded = item["isUploaded"] as! Bool
            return !isUploaded
        }
        result.sort { (v1, v2) -> Bool in
            return v1.createdTime.timeIntervalSince1970 > v2.createdTime.timeIntervalSince1970 ? true : false
        }
        return result
    }
    open func getLastImageInfo() -> YTKKeyValueItem? {
        let result = self.getCurrentRepoImagesInfo()
        return result.count > 0 ? result[0] : nil
    }
    // MARK: - save md file
    open func saveMDFileInfo(filePath: String, fileName: String, isUploaded: Bool, t_repoInfo: Dictionary<String, String>? = nil) {
        let repoInfo = self.getRepoInfo()
        if (t_repoInfo == nil) {
            if (repoInfo == nil) {
                self.store.put([
                    "imagePath": filePath,
                    "isUploaded": isUploaded
                ], withId: fileName, intoTable: self.mdFileInfoTable)
                return
            }
        }
        self.store.put([
            "filePath": filePath,
            "isUploaded": isUploaded,
            "repoId": t_repoInfo != nil ? t_repoInfo!["repoId"]! : repoInfo!["repoId"]! ,
            "p": t_repoInfo != nil ? t_repoInfo!["p"]! : repoInfo!["p"]!
        ], withId: fileName, intoTable: self.mdFileInfoTable)
    }
    open func getMDFilesInfo() -> Array<YTKKeyValueItem> {
        let r = self.store.getAllItems(fromTable: self.mdFileInfoTable) as? [YTKKeyValueItem] ?? []
        return r
    }
}
