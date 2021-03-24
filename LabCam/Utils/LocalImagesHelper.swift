//
//  LocalImagesHelper.swift
//  LabCam
//
//  Created by ysq on 2021/2/1.
//

import Foundation
import UIKit
import Lantern

class LocalImagesHelper {
    private let db = DatabaseUtil()
    func showImagesFromPath(nav: UINavigationController) {
        let imagesInfo = self.db.getCurrentRepoImagesInfo()
        if (imagesInfo.count == 0) {
            return
        }
        let lantern = Lantern()
        lantern.numberOfItems = {
            imagesInfo.count
        }
        lantern.pageIndicator = LanternDefaultPageIndicator()
        lantern.reloadCellAtIndex = { context in
            let lanternCell = context.cell as? LanternImageCell
            let indexPath = IndexPath(item: context.index, section: 0)
            do {
                let rootPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
                let imagePath = "\(rootPath)/\(imagesInfo[indexPath.row].itemId!)"
                let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
                lanternCell?.imageView.image = UIImage(data: imageData)
            } catch {
                print("error")
            }
        }
        lantern.isPreviousNavigationBarHidden = false
        lantern.show(method: .present(fromVC: nil, embed: nil))
    }
    func saveAndUploadImage(image: UIImage) -> String {
        let fileManager = FileManager.default
        let rootPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyyMMdd_HHmmssSSS"
        let imageName = "LabCam_img_\(dateFormat.string(from: Date())).jpg"
        let imagePath = "\(rootPath)/\(imageName)"
        let imageData = image.jpegData(compressionQuality: 1.0)
        let result = fileManager.createFile(atPath: imagePath, contents: imageData, attributes: nil)
        if (result) {
            self.db.saveImageInfo(imagePath: imagePath, imageName: imageName, isUploaded: false)
            (UIApplication.shared.delegate as! AppDelegate).uploadImagesUtil.startUpload()
        }
        return imageName
    }
}
