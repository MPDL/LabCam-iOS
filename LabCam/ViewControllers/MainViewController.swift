//
//  MainViewController.swift
//  LabCam
//
//  Created by ysq on 2021/2/1.
//

import UIKit
import AVFoundation
import Lantern
import MBProgressHUD
import MLKit

class MainViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {

    private var isOCRMode: Bool = false
    @IBOutlet weak var preivewLastImageView: UIView!
    @IBOutlet weak var previewLastImageImageView: UIImageView!
    @IBOutlet weak var takePhoneButton: UIButton!
    @IBOutlet weak var previewView: PreviewView!
    private var session: AVCaptureSession!
    private var leftMenuButton: UIButton?
    private var rightOCRButton: UIButton?
    private var rightLightButton: UIButton?
    private var device: AVCaptureDevice?
    private var deviceDiscoverySession: AVCaptureDevice.DiscoverySession?
    private var position: AVCaptureDevice.Position = .back
    private var photoOutput: AVCapturePhotoOutput?
    private var flashMode: AVCaptureDevice.FlashMode = .off
    private var localImagesHelper: LocalImagesHelper = LocalImagesHelper()
    private var localMDFilesHelper: LocalMDFilesHelper = LocalMDFilesHelper()
    private var focusImageView: UIImageView?
    private var currentZoomFactor: CGFloat = 1
    private var db = DatabaseUtil()
    private var api = LCApi()
    private var firstCheck = true
    private var tmpView: UIView?
    private var camInput: AVCaptureDeviceInput?
    @IBOutlet weak var leftMenuView: UIView!
    @IBOutlet weak var leftMenuViewWidthLayoutConstrain: NSLayoutConstraint!
    @IBOutlet weak var leftMenuContentView: UIView!
    @IBOutlet weak var uploadViaLabel: UILabel!
    @IBOutlet weak var uploadNetworkViaLabel: UILabel!
    @IBOutlet weak var uploadRepoNameLabel: UILabel!
    @IBOutlet weak var uploadNetworkNameLabel: UILabel!
    @IBOutlet weak var ocrTextView: UIView!
    @IBOutlet weak var ocrTextViewTipLabel: UILabel!
    @IBOutlet weak var ocrTextViewTextView: UITextView!
    @IBOutlet weak var togglePositionButton: UIButton!
    private var lastUploadImageID = ""
    private var lastOCRTime: TimeInterval = 0
    private var lastSetPreviewBgImageViewTime: TimeInterval = 0
    private var isShowingRepoIsNotFound = false
    private var loadingHud: MBProgressHUD?
    private var tipHud: MBProgressHUD?
    private var ocrTextViewTextViewSize: CGSize!
    @IBOutlet var preViewTapGesture: UITapGestureRecognizer!
    @IBOutlet weak var uploadNetworkSelectView: UIView!
    @IBOutlet weak var uploadNetworkViaCellularView: UIImageView!
    @IBOutlet weak var uploadNetworkViaWiFiView: UIImageView!
    private var handleOCRTag: Int = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.checkRepo()
        self.setupPreviewLastImage()
        (UIApplication.shared.delegate as? AppDelegate)?.uploadImagesUtil.startUpload()
        (UIApplication.shared.delegate as? AppDelegate)?.uploadMDFilesUtil.startUpload()
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    
    deinit {
        self.tmpView?.removeFromSuperview()
        NotificationCenter.default.removeObserver(self, name: Notification.Name(UploadImagesUtil.uploadSuccessNotiName), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(UploadImagesUtil.uploadNotFoundNotiName), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(UploadMDFilesUtil.uploadNotFoundNotiName), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AppDelegate.noticeAPPActive, object: nil)
    }
    
    // MARK: - check and alert
    
    @objc private func checkRepo() {
        guard let repoInfo = self.db.getRepoInfo() else {
            self.alertRepoError()
            return
        }
        if (self.firstCheck) {
            if (self.loadingHud == nil) {
                self.loadingHud = MBProgressHUD.showAdded(to: self.view, animated: true)
            }
            self.loadingHud?.mode = .indeterminate
            self.loadingHud?.label.text = "LOAD..."
            if (self.loadingHud != nil && self.loadingHud!.isHidden) {
                self.loadingHud?.show(animated: true)
            }
        }
        self.api.getUploadLinkWithRepoInfo(repoId: repoInfo["repoId"]!, p: repoInfo["p"]!) { [weak self] (_) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.loadingHud?.hide(animated: true)
            weakSelf.showRepoTip(repoInfo: repoInfo)
            weakSelf.firstCheck = false
        } failure: { [weak self] (notFound) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.loadingHud?.hide(animated: true)
            if (notFound) {
                weakSelf.alertRepoError()
            } else {
                weakSelf.showRepoTip(repoInfo: repoInfo)
            }
        }
    }
    
    private func showRepoTip(repoInfo: Dictionary<String, String>) {
        let imagesCount = self.db.getCurrentRepoImagesInfo().count
        if (imagesCount == 0) {
            if (self.firstCheck) {
                self.tipHud = MBProgressHUD.showAdded(to: self.view, animated: true)
                self.tipHud?.offset = CGPoint(x: 0, y: UIScreen.main.bounds.height / 2.0 - 200)
                self.tipHud?.mode = .text
                self.tipHud?.label.numberOfLines = 0
                self.tipHud?.label.text = "Upload dir: \(repoInfo["mainRepoName"]!)\(repoInfo["p"]!) \nUpload via: \(self.db.userNetworkIsOnlyWifi() ? "Wi-Fi Only" : "Cellular")."
                self.tipHud?.hide(animated: true, afterDelay: 2)
            }
        } else {
            let userOnlyWifi = self.db.userNetworkIsOnlyWifi()
            guard let status = ReachabilityManager.shared.reachabilityManager?.status else {
                return
            }
            self.tipHud = MBProgressHUD.showAdded(to: self.view, animated: true)
            self.tipHud?.offset = CGPoint(x: 0, y: UIScreen.main.bounds.height / 2.0 - 200)
            self.tipHud?.mode = .text
            self.tipHud?.label.numberOfLines = 0
            if (status == .notReachable) {
                self.tipHud?.label.text = "\(imagesCount) items will upload to \(repoInfo["mainRepoName"]!)\(repoInfo["p"]!) when connected to the Internet."
            } else if (userOnlyWifi && status == .reachable(.cellular)) {
                self.tipHud?.label.text = "\(imagesCount) items will upload to \(repoInfo["mainRepoName"]!)\(repoInfo["p"]!) when connected to Wi-Fi."
            } else {
                self.tipHud?.label.text = "Uploading \(imagesCount) items to \(repoInfo["mainRepoName"]!)\(repoInfo["p"]!) via \(self.db.userNetworkIsOnlyWifi() ? "Wi-Fi" : "Cellular")."
            }
            self.tipHud?.hide(animated: true, afterDelay: 5)
        }
    }
    
    @objc private func alertRepoError() {
        if (self.isShowingRepoIsNotFound) {
            return
        }
        self.isShowingRepoIsNotFound = true
        let alert = UIAlertController(title: "Upload not successful", message: "Target folder does not exist, please select another one.", preferredStyle: .alert)
        let change = UIAlertAction(title: "CHANGE", style: .default) { [weak self] (_) in
            guard let weakSelf = self else {
                return
            }
            let selectRepoVC = SelectRepoViewController(nibName: "SelectRepoViewController", bundle: nil)
            selectRepoVC.confirmActionBlock = {() in
                weakSelf.isShowingRepoIsNotFound = false
                (UIApplication.shared.delegate as? AppDelegate)?.uploadImagesUtil.startUpload()
                (UIApplication.shared.delegate as? AppDelegate)?.uploadMDFilesUtil.startUpload()
                selectRepoVC.dismiss(animated: true, completion: nil)
                weakSelf.updateLeftMenuViewText()
            }
            selectRepoVC.cancelActionBlock = {() in
                weakSelf.checkRepo()
                weakSelf.isShowingRepoIsNotFound = false
            }
            weakSelf.present(selectRepoVC, animated: true, completion: nil)
        }
        alert.addAction(change)
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc private func handleUploadSuccess(noti: Notification) {
        self.setupPreviewLastImage()
    }
    
    // MARK: - setup
    
    private func setup() {
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.checkRepo), name: AppDelegate.noticeAPPActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.alertRepoError), name: Notification.Name(UploadImagesUtil.uploadNotFoundNotiName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.alertRepoError), name: Notification.Name(UploadMDFilesUtil.uploadNotFoundNotiName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.handleUploadSuccess(noti:)), name: Notification.Name(UploadImagesUtil.uploadSuccessNotiName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.orientationDidChangeNotification(noti:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        // left menu
        self.leftMenuButton = UIButton(frame: CGRect.init(x: 8, y: 0, width: 18, height: 22))
        self.leftMenuButton?.addTarget(self, action: #selector(MainViewController.clickOnLeftMenu), for: .touchUpInside)
        self.leftMenuButton?.setBackgroundImage(UIImage(named: "more"), for: .normal)
        self.leftMenuButton?.lzh_expandSize(size: 10)
        let leftCustomView: UIView = UIView(frame: CGRect(x: 0, y: 0, width: self.leftMenuButton!.frame.width + 20, height: self.leftMenuButton!.frame.height))
        leftCustomView.addSubview(self.leftMenuButton!)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftCustomView)
        // right buttons
        self.rightOCRButton = UIButton(frame: CGRect.init(x: 0, y: 0, width: 35, height: 22))
        self.rightOCRButton?.addTarget(self, action: #selector(MainViewController.clickOnToggleOCRMode), for: .touchUpInside)
        self.rightOCRButton?.setBackgroundImage(UIImage(named: "OCR-"), for: .normal)
        let rightOCRCustomView: UIView = UIView(frame: self.rightOCRButton!.frame)
        rightOCRCustomView.addSubview(self.rightOCRButton!)
        self.rightLightButton = UIButton(frame: CGRect.init(x: 25, y: 0, width: 15, height: 22))
        self.rightLightButton?.addTarget(self, action: #selector(MainViewController.clickOnToggleLightMode), for: .touchUpInside)
        self.rightLightButton?.setBackgroundImage(UIImage(named: "turnOffFlash"), for: .normal)
        let rightLightCustomView: UIView = UIView(frame: CGRect(x: 0, y: 0, width: self.rightLightButton!.frame.size.width + 25 + 8, height: self.rightLightButton!.frame.size.height))
        rightLightCustomView.addSubview(self.rightLightButton!)
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: rightLightCustomView), UIBarButtonItem(customView: rightOCRCustomView)]
        // preview
        self.preivewLastImageView.layer.borderWidth = 1
        self.preivewLastImageView.layer.borderColor = UIColor.white.cgColor
        self.preivewLastImageView.layer.cornerRadius = 7
        self.preivewLastImageView.clipsToBounds = true
        // take photo
        self.takePhoneButton.layer.cornerRadius = 30
        self.takePhoneButton.layer.borderColor = UIColor.white.cgColor
        self.takePhoneButton.layer.borderWidth = 5
        self.takePhoneButton.clipsToBounds = true
        self.takePhoneButton.setBackgroundImage(UIImageUtil.imageWithColor(color: UIColor(red: 185/255.0, green: 185/255.0, blue: 185/255.0, alpha: 1), width: 60, height: 60), for: .normal)
        self.takePhoneButton.setBackgroundImage(UIImageUtil.imageWithColor(color: UIColor(red: 107/255.0, green: 209/255.0, blue: 190/255.0, alpha: 1), width: 60, height: 60), for: .highlighted)
        self.ocrTextViewTextView.textContainer.lineFragmentPadding = 0.0
        self.ocrTextViewTextView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        self.updateLeftMenuViewText()
        self.setupCamera()
        self.setupBarButtonStatus()
        self.setupPreviewLastImage()
    }
    
    private func updateLeftMenuViewText() {
        self.leftMenuContentView.layer.shadowColor = UIColor.gray.cgColor
        self.leftMenuContentView.layer.shadowOffset = CGSize(width:1, height:1)
        self.leftMenuContentView.layer.shadowRadius = 10
        self.leftMenuContentView.layer.shadowOpacity = 0.1
        self.leftMenuContentView.layer.cornerRadius = 8
        self.leftMenuContentView.clipsToBounds = true
        self.uploadViaLabel.text = "Upload photos to \(ServerTypeHeler.getServerNameWithUrl(url: self.db.getMainUrl()))"
        if let repo = self.db.getRepoInfo() {
            self.uploadRepoNameLabel.text = repo["mainRepoName"]! + repo["p"]!
        } else {
            self.uploadRepoNameLabel.text = ""
        }
        self.uploadNetworkViaLabel.text = "Upload photos to \(ServerTypeHeler.getServerNameWithUrl(url: self.db.getMainUrl())) via"
        self.uploadNetworkNameLabel.text = self.db.userNetworkIsOnlyWifi() ? "Wi-Fi Only" : "Cellular"
    }
    
    // MARK: - update preview last image
    
    private func setupPreviewLastImage() {
        guard let item = self.db.getLastImageInfo() else {
            self.previewLastImageImageView.backgroundColor = .clear
            self.previewLastImageImageView.image = nil
            return
        }
        do {
            self.previewLastImageImageView.backgroundColor = UIColor(red: 185/255.0, green: 185/255.0, blue: 185/255.0, alpha: 1)
            let rootPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
            let imagePath = "\(rootPath)/\(item.itemId!)"
            let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            self.previewLastImageImageView.image = UIImage(data: imageData)
        } catch {
            print("error")
        }
    }
    
    private func setupBarButtonStatus() {
        if (self.isOCRMode) {
            self.rightOCRButton?.setImage(UIImage(named: "OCR"), for: .normal)
        } else {
            self.rightOCRButton?.setImage(UIImage(named: "OCR-"), for: .normal)
        }
        if (self.device != nil) {
            switch self.flashMode {
            case .auto:
                self.rightLightButton?.setBackgroundImage(UIImage(named: "ic_flash_auto"), for: .normal)
            case .off:
                self.rightLightButton?.setBackgroundImage(UIImage(named: "turnOffFlash"), for: .normal)
            case .on:
                self.rightLightButton?.setBackgroundImage(UIImage(named: "ic_flash_on"), for: .normal)
            default:
                print("default")
            }
        }
    }
    
    // MARK: - nav items
    
    @objc private func clickOnLeftMenu() {
        self.handleToggleMenuView()
        self.hiddenUploadNetworkSelectView()
    }
    @IBAction func clickOnLogout(_ sender: Any) {
        let alert = UIAlertController(title: "Logout", message: "Are you sure to logout?", preferredStyle: .alert)
        let cancel = UIAlertAction(title: "CANCEL", style: .default, handler: nil)
        let logout = UIAlertAction(title: "LOGOUT", style: .default) { (_) in
            self.db.removeAllData()
            (UIApplication.shared.delegate as! AppDelegate).setupMainPage()
        }
        alert.addAction(cancel)
        alert.addAction(logout)
        self.present(alert, animated: true, completion: nil)
    }
    @IBAction func clickOnSelectRepo(_ sender: Any) {
        let selectRepoVC = SelectRepoViewController(nibName: "SelectRepoViewController", bundle: nil)
        selectRepoVC.confirmActionBlock = {() in
            selectRepoVC.dismiss(animated: true, completion: nil)
            self.updateLeftMenuViewText()
            self.hiddenLeftMenuView()
            (UIApplication.shared.delegate as? AppDelegate)?.uploadImagesUtil.startUpload()
            (UIApplication.shared.delegate as? AppDelegate)?.uploadMDFilesUtil.startUpload()
        }
        self.present(selectRepoVC, animated: true, completion: nil)
    }
    @IBAction func clickOnUploadNetwork(_ sender: UIButton) {
        self.hiddenLeftMenuView()
        self.uploadNetworkSelectView.alpha = 0
        self.uploadNetworkSelectView.isHidden = false
        UIView.animate(withDuration: 0.5) {
            self.uploadNetworkSelectView.alpha = 1
        }
        self.uploadNetworkViaCellularView.image = UIImage(named: self.db.userNetworkIsOnlyWifi() ? "unselect" : "select")
        self.uploadNetworkViaWiFiView.image = UIImage(named: !self.db.userNetworkIsOnlyWifi() ? "unselect" : "select")
    }
    
    @IBAction func clickOnViaCellular(_ sender: Any) {
        self.db.saveUserNetworkIsOnlyWifi(onlyWifi: false)
        self.uploadNetworkViaCellularView.image = UIImage(named: self.db.userNetworkIsOnlyWifi() ? "unselect" : "select")
        self.uploadNetworkViaWiFiView.image = UIImage(named: !self.db.userNetworkIsOnlyWifi() ? "unselect" : "select")
        self.updateLeftMenuViewText()
        self.hiddenLeftMenuView()
        (UIApplication.shared.delegate as? AppDelegate)?.uploadImagesUtil.startUpload()
        (UIApplication.shared.delegate as? AppDelegate)?.uploadMDFilesUtil.startUpload()
        self.hiddenUploadNetworkSelectView()
    }
    
    @IBAction func clickOnViaWiFiOnly(_ sender: Any) {
        self.db.saveUserNetworkIsOnlyWifi(onlyWifi: true)
        self.uploadNetworkViaCellularView.image = UIImage(named: self.db.userNetworkIsOnlyWifi() ? "unselect" : "select")
        self.uploadNetworkViaWiFiView.image = UIImage(named: !self.db.userNetworkIsOnlyWifi() ? "unselect" : "select")
        self.updateLeftMenuViewText()
        self.hiddenLeftMenuView()
        (UIApplication.shared.delegate as? AppDelegate)?.uploadImagesUtil.startUpload()
        (UIApplication.shared.delegate as? AppDelegate)?.uploadMDFilesUtil.startUpload()
        self.hiddenUploadNetworkSelectView()
    }
    
    @IBAction func clickOnUploadNetworkSelectView(_ sender: Any) {
        self.hiddenUploadNetworkSelectView()
    }
    
    private func hiddenUploadNetworkSelectView() {
        UIView.animate(withDuration: 0.5) {
            self.uploadNetworkSelectView.alpha = 0
        } completion: { (_) in
            self.uploadNetworkSelectView.isHidden = true
        }
    }
    
    private func showLeftMenuView() {
        if (self.tmpView == nil) {
            self.tmpView = UIView(frame: CGRect(x: 10, y: UIApplication.shared.statusBarFrame.height + self.navigationController!.navigationBar.frame.height - 7, width: UIScreen.main.bounds.width - 20, height: 140))
            self.tmpView?.addSubview(self.leftMenuView)
            self.leftMenuViewWidthLayoutConstrain.constant = UIScreen.main.bounds.width - 20
            (UIApplication.shared.delegate as! AppDelegate).window?.addSubview(self.tmpView!)
        }
        let isLeftOrRight = false
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        self.tmpView?.frame = CGRect(x: 10, y: isLeftOrRight && isPhone ? (self.navigationController!.navigationBar.frame.height - 7) : (UIApplication.shared.statusBarFrame.height + self.navigationController!.navigationBar.frame.height - 7), width: UIScreen.main.bounds.width - 20, height: 140)
        self.leftMenuViewWidthLayoutConstrain.constant = UIScreen.main.bounds.width - 20
        if (self.leftMenuView.isHidden) {
            self.leftMenuView.alpha = 0
            self.tmpView?.isHidden = false
            self.leftMenuView.isHidden = false
            UIView.animate(withDuration: 0.3) {
                self.leftMenuView.alpha = 1
            }
        }
    }
    private func hiddenLeftMenuView() {
        if (!self.leftMenuView.isHidden) {
            UIView.animate(withDuration: 0.3) {
                self.leftMenuView.alpha = 0
            } completion: { (_) in
                self.leftMenuView.isHidden = true
                self.tmpView?.isHidden = true
            }
        }
    }
    private func handleToggleMenuView() {
        if (self.leftMenuView.isHidden) {
            self.showLeftMenuView()
        } else {
            self.hiddenLeftMenuView()
        }
    }
    @objc private func clickOnToggleOCRMode() {
        self.hiddenUploadNetworkSelectView()
        self.isOCRMode = !self.isOCRMode
        if (self.isOCRMode) {
            self.showORCView()
        } else {
            self.hiddenOCRView()
        }
        self.setupBarButtonStatus()
        self.hiddenLeftMenuView()
    }
    @objc private func clickOnToggleLightMode() {
        self.hiddenUploadNetworkSelectView()
        self.hiddenLeftMenuView()
        if (self.device == nil) {
            return
        }
        switch self.flashMode {
        case .off:
            if (self.device!.isTorchModeSupported(.auto)) {
                self.flashMode = .auto
            } else if (self.device!.isTorchModeSupported(.on)) {
                self.flashMode = .on
            }
        case .on:
            self.flashMode = .off
        case .auto:
            if (self.device!.isTorchModeSupported(.on)) {
                self.flashMode = .on
            } else {
                self.flashMode = .off
            }
        default:
            print("default")
        }
        self.setupBarButtonStatus()
    }
    
    // MARK: - OCR
    
    private func showORCView() {
        if (self.ocrTextView.isHidden) {
            self.ocrTextView.alpha = 0
            self.ocrTextView.isHidden = false
            UIView.animate(withDuration: 0.3) {
                self.ocrTextView.alpha = 1
            }
            UIView.animate(withDuration: 0.3) {
                self.ocrTextView.alpha = 1
            } completion: { (_) in
                self.handleOCRTag = self.handleOCRTag + 1
                self.orientationDidChangeNotification(noti: Notification(name: UIDevice.orientationDidChangeNotification))
            }

        }
    }
    private func hiddenOCRView() {
        if (!self.ocrTextView.isHidden) {
            UIView.animate(withDuration: 0.3) {
                self.ocrTextView.alpha = 0
            } completion: { (_) in
                self.ocrTextView.isHidden = true
            }
        }
    }
    private func handleToggleOCRView() {
        if (self.ocrTextView.isHidden) {
            self.showLeftMenuView()
        } else {
            self.hiddenLeftMenuView()
        }
    }
    // MARK: - bottom buttons
    
    @IBAction func clickOnPreviewImages(_ sender: Any) {
        self.hiddenLeftMenuView()
        self.localImagesHelper.showImagesFromPath(nav: self.navigationController!)
    }
    @IBAction func clickOnTogglePosition(_ sender: Any) {
        self.hiddenLeftMenuView()
        self.position = self.position.rawValue == AVCaptureDevice.Position.back.rawValue ? .front : .back
        self.cameraTogglePosition()
    }
    @IBAction func clickOnTakePhoto(_ sender: Any) {
        print("take photo")
        self.hiddenLeftMenuView()
        if (self.db.getRepoInfo() == nil) {
            self.alertRepoError()
            return
        }
        if (self.isOCRMode) {
            self.localMDFilesHelper.saveAndUploadFile(fileText: self.ocrTextViewTextView.text)
            UIView.animate(withDuration: 0.5) { [weak self] () in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.ocrTextViewTextView.alpha = 0
                weakSelf.ocrTextView.alpha = 0
            } completion: { [weak self] (finish) in
                guard let weakSelf = self else {
                    return
                }
                if (finish) {
                    UIView.animate(withDuration: 0.3) {
                        weakSelf.ocrTextViewTextView.alpha = 1
                        weakSelf.ocrTextViewTextView.text = ""
                        weakSelf.ocrTextView.alpha = 1
                    }
                }
            }
        }
        guard self.device != nil, self.session.isRunning else {
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    @IBAction func longPressTakePhoto(_ sender: UILongPressGestureRecognizer) {
        if (self.isOCRMode) {
            return
        }
        self.clickOnTakePhoto(sender)
        print("longpress take photo")
    }
    
    // MARK: - Camera Delegate and Setup
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if (error != nil) {
            return
        }
        if let imageData: Data = photo.fileDataRepresentation() {
            if let image = UIImage(data: imageData) {
                let t_image = image.crop43()
                UIImageWriteToSavedPhotosAlbum(t_image, nil, nil, nil)
                self.lastUploadImageID = self.localImagesHelper.saveAndUploadImage(image: t_image)
            }
        } else {
        }
        self.setupPreviewLastImage()
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if (!self.isOCRMode) {
            return
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        if (self.lastOCRTime != 0) {
            let now = Date().timeIntervalSince1970
            // 间隔3秒
            if (now - self.lastOCRTime < 3) {
                return
            }
        }
        self.lastOCRTime = Date().timeIntervalSince1970
        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = UIUtilities.imageOrientation(fromDevicePosition: self.position == .front ? .front : .back)
        visionImage.orientation = orientation
        var recognizedText: Text
        do {
            recognizedText = try TextRecognizer.textRecognizer().results(in: visionImage)
        } catch let error {
            print("Failed to recognize text with error: \(error.localizedDescription).")
            return
        }
        weak var weakSelf = self
        DispatchQueue.main.sync {
            guard let strongSelf = weakSelf else {
                return
            }
            strongSelf.ocrTextViewTextView.text = ""
            for block in recognizedText.blocks {
                strongSelf.ocrTextViewTextView.text = strongSelf.ocrTextViewTextView.text + block.text + "\n"
                for line in block.lines {
                    for element in line.elements {
                    }
                }
            }
        }
    }
    
    func setupCamera() {
        self.session = AVCaptureSession()
        previewView.session = session
        self.deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: self.position)
        if (self.deviceDiscoverySession != nil) {
            for device in self.deviceDiscoverySession!.devices as [AVCaptureDevice]{
                if device.position == self.position {
                    self.device = device
                    break
                }
            }
            if (self.device == nil) {
                return
            }
            do {
                let camInput = try AVCaptureDeviceInput(device: self.device!)
                if session.canAddInput(camInput) {
                    self.camInput = camInput
                    session.addInput(camInput)
                }
            } catch {
                print("no camera")
            }
            session.sessionPreset = .high
            guard auth() else {
                return
            }
            let videoOutput = AVCaptureVideoDataOutput()
            let queue = DispatchQueue(label: "buffer queue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
            
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            if self.session.canAddOutput(self.photoOutput!) {
                self.session.addOutput(self.photoOutput!)
            }
            session.startRunning()
        }
    }
    
    private func cameraTogglePosition() {
        self.deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: self.position)
        if (self.deviceDiscoverySession != nil) {
            for device in self.deviceDiscoverySession!.devices as [AVCaptureDevice]{
                if device.position == self.position {
                    self.device = device
                    break
                }
            }
            if (self.device == nil) {
                return
            }
            do {
                let camInput = try AVCaptureDeviceInput(device: self.device!)
                session.beginConfiguration()
                if (self.camInput != nil) {
                    session.removeInput(self.camInput!)
                }
                if session.canAddInput(camInput) {
                    self.camInput = camInput
                    session.addInput(camInput)
                } else {
                    session.addInput(self.camInput!)
                }
                session.commitConfiguration()
            } catch {
                print("no camera")
            }
        }
    }
    
    private func auth() -> Bool{
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video,
                                          completionHandler: { (granted:Bool) -> Void in
                                            if granted {
                                                DispatchQueue.main.async {
                                                    self.previewView.setNeedsDisplay()
                                                }
                                            }
            })
           return true
        case .authorized:
            return true
        case .denied, .restricted: return false
        @unknown default:
            fatalError()
        }
    }
    
    
    // MARK: - tap and pinch
    
    @IBAction func tapPreview(_ sender: UITapGestureRecognizer) {
        self.hiddenLeftMenuView()
        let point = sender.location(in: self.previewView)
        let size = self.previewView.bounds.size
        let focusPoint = CGPoint(x: point.y / size.height, y: 1 - point.x / size.width)
        do {
            try self.device?.lockForConfiguration()
            if (self.device!.isFocusModeSupported(.autoFocus)) {
                self.device?.focusPointOfInterest = focusPoint
                self.device?.focusMode = .autoFocus
            }
            self.device?.unlockForConfiguration()
        } catch {
            print("error")
        }
        if (self.focusImageView == nil) {
            self.focusImageView = UIImageView(image: UIImage(named: "focus"))
            self.focusImageView?.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            self.focusImageView?.isHidden = true
            self.previewView.addSubview(self.focusImageView!)
        }
        self.focusImageView?.center = point
        self.focusImageView?.isHidden = false
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.focusImageView?.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        } completion: { [weak self] (_) in
            guard let weakSelf = self else {
                return
            }
            UIView.animate(withDuration: 0.5) {
                weakSelf.focusImageView?.transform = CGAffineTransform.identity
            } completion: { (_) in
                weakSelf.focusImageView?.isHidden = true
            }
        }
    }
    
    @IBAction func pinchPreview(_ sender: UIPinchGestureRecognizer) {
        self.hiddenLeftMenuView()
        if (self.device == nil) {
            return
        }
        let minZoomFactor = self.device!.minAvailableVideoZoomFactor
        let maxZoomFactor = self.device!.maxAvailableVideoZoomFactor
        if (sender.state == .began) {
            self.currentZoomFactor = self.device!.videoZoomFactor
        }
        if (sender.state == .changed) {
            let currentZoomFactor = self.currentZoomFactor * sender.scale
            if (currentZoomFactor < maxZoomFactor && currentZoomFactor > minZoomFactor) {
                do {
                    try self.device?.lockForConfiguration()
                    self.device?.videoZoomFactor = currentZoomFactor
                    self.device?.unlockForConfiguration()
                } catch {
                    print("error")
                }
            }
        }
    }
    
    
    // MARK: - orientation
    
    @objc private func orientationDidChangeNotification(noti: Notification) {
        print("orientationDidChangeNotification")
        self.hiddenLeftMenuView()
        if (self.handleOCRTag == 1) {
            let transform = CGAffineTransform.identity
            self.ocrTextViewTextView.transform = transform
            self.ocrTextViewTextView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: self.preivewLastImageView.frame.minY - 40)
            self.handleOCRTag += 1
        }
        var angle: CGFloat = 0
        switch UIDevice.current.orientation {
        case .portrait:
            angle = 0
        case .landscapeLeft, .landscapeRight:
            if (UIDevice.current.orientation == .landscapeLeft) {
                angle = CGFloat.pi / 2
            } else {
                angle = CGFloat.pi / 2 + CGFloat.pi
            }
        case .portraitUpsideDown:
            angle = CGFloat.pi
        case .unknown:
            return
        case .faceDown:
            return
        case .faceUp:
            angle = 0
        @unknown default:
            return
        }
        
        UIView.animate(withDuration: 0.3) {
            let transform = angle == 0 ? CGAffineTransform.identity : CGAffineTransform(rotationAngle: angle)
            self.leftMenuButton?.transform = transform
            self.rightOCRButton?.transform = transform
            self.rightLightButton?.transform = transform
            self.previewLastImageImageView.transform = transform
            self.togglePositionButton.transform = transform
        }
        let transform = angle == 0 ? CGAffineTransform.identity : CGAffineTransform(rotationAngle: angle)
        self.ocrTextViewTextView.transform = transform
        self.ocrTextViewTextView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: self.preivewLastImageView.frame.minY - 40)
    }

}
