//
//  LocalMDFilesHelper.swift
//  LabCam
//
//  Created by ysq on 2021/2/2.
//

import Foundation
import UIKit
import Lantern

class LocalMDFilesHelper {
    private let db = DatabaseUtil()
    func saveAndUploadFile(fileText: String) {
        let fileManager = FileManager.default
        let rootPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyyMMdd_HHmmssSSS"
        let fileName = "LabCam_img_\(dateFormat.string(from: Date())).md"
        let filePath = "\(rootPath)/\(fileName)"
        let fileData = fileText.data(using: .utf8)
        let result = fileManager.createFile(atPath: filePath, contents: fileData, attributes: nil)
        if (result) {
            self.db.saveMDFileInfo(filePath: filePath, fileName: fileName, isUploaded: false)
            (UIApplication.shared.delegate as! AppDelegate).uploadMDFilesUtil.startUpload()
        }
    }
}
