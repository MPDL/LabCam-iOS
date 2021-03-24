//
//  AppDelegate.swift
//  LabCam
//
//  Created by ysq on 2021/1/31.
//

import UIKit
import IQKeyboardManagerSwift

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    static let noticeAPPActive = Notification.Name("noticeAPPActive")
    private let db = DatabaseUtil()
    var uploadImagesUtil = UploadImagesUtil()
    var uploadMDFilesUtil = UploadMDFilesUtil()
    var window: UIWindow?
    var loginViewController: ViewController?
    var mainViewController: MainViewController?
    var navigationController: MainNavigationViewController?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (accepted, error) in
        }
        UINavigationBar.appearance().barTintColor = UIColor(red: 86/255.0, green: 96/255.0, blue: 105/255.0, alpha: 1.0)
        IQKeyboardManager.shared.enable = true
        ReachabilityManager.shared.startNetworkReachabilityObserver()
        self.setupMainPage()
        self.uploadImagesUtil.startUpload()
        self.uploadMDFilesUtil.startUpload()
        return true
    }
    

    public func setupMainPage() {
        let r = self.db.userIsLogined()
        if (r) {
            mainViewController = MainViewController(nibName: "MainViewController", bundle: nil)
            mainViewController?.view.backgroundColor = .white
            navigationController = MainNavigationViewController(rootViewController: mainViewController!)
            self.window?.rootViewController = navigationController
        } else {
            loginViewController = (UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LoginViewController") as! ViewController)
            self.window?.rootViewController = loginViewController
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
    }
    func applicationDidEnterBackground(_ application: UIApplication) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: DispatchTime.now() + 15) {[weak self] () in
            guard let weakSelf = self else {
                return
            }
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .background {
                    if (weakSelf.db.getCurrentRepoImagesInfo().count > 0) {
                        let content = UNMutableNotificationContent()
                        content.title = "LabCam"
                        content.body = "Upload paused. Photos will upload to the target folder while you are using LabCam."
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let requestIdentifier = "com.labcam.notification"
                        let request = UNNotificationRequest(identifier: requestIdentifier,
                                                            content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request) { error in
                        }
                    }
                }
            }
        }
        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "kBgTaskName") {
            if (self.backgroundTaskIdentifier != nil && self.backgroundTaskIdentifier! != .invalid) {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskIdentifier!)
                self.backgroundTaskIdentifier = .invalid
            }
        }
    }
    func applicationWillEnterForeground(_ application: UIApplication) {
       if (self.backgroundTaskIdentifier != nil) {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskIdentifier!)
        }
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(name: AppDelegate.noticeAPPActive, object: nil, userInfo: nil)
    }
    func applicationWillTerminate(_ application: UIApplication) {
    }
}

