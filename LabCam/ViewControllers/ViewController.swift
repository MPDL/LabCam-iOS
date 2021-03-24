//
//  ViewController.swift
//  LabCam
//
//  Created by ysq on 2021/1/31.
//

import UIKit
import MBProgressHUD
import SafariServices

class ViewController: UIViewController {

    private var type: ServerType! = .KEEPER
    private var shownPassword = false
    @IBOutlet weak var toggleTypeView: UIView!
    @IBOutlet weak var serverTypeLabel: UILabel!
    @IBOutlet weak var serverTypeTextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var passwordIconImageView: UIImageView!
    @IBOutlet weak var createAccountButton: UIButton!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    private let api = LCApi()
    private let db = DatabaseUtil()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.textFieldValueChanged(_:)), name: UITextField.textDidChangeNotification, object: self.serverTypeTextField)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.textFieldValueChanged(_:)), name: UITextField.textDidChangeNotification, object: self.usernameTextField)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.textFieldValueChanged(_:)), name: UITextField.textDidChangeNotification, object: self.passwordTextField)
        
//        self.usernameTextField.text = "labcam-support@mpdl.mpg.de"
//        self.passwordTextField.text = "labcam+0110"
        self.db.saveMainUrl(url: self.serverTypeTextField.text!)
        if #available(iOS 12.0, *) {
            self.passwordTextField.textContentType = .oneTimeCode
        } else {
        }
        self.checkLoginStatu()
        self.checkPasswordStatu()
        self.checkAccountActionStatu()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: self.serverTypeTextField)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: self.usernameTextField)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: self.passwordTextField)
    }
    
    // MARK: - 检查登陆
    
    private func checkLoginStatu() {
        if (self.serverTypeTextField.text != nil && self.serverTypeTextField.text!.count > 0 && self.usernameTextField.text != nil && self.usernameTextField.text!.count > 0 && self.passwordTextField.text != nil && self.passwordTextField.text!.count > 0) {
            self.loginButton.backgroundColor = UIColor(red: 107/255.0, green: 209/255.0, blue: 190/255.0, alpha: 1)
            self.loginButton.isEnabled = true
        } else {
            self.loginButton.backgroundColor = UIColor(red: 185/255.0, green: 185/255.0, blue: 185/255.0, alpha: 1)
            self.loginButton.isEnabled = false
        }
    }
    
    private func checkPasswordStatu() {
        if (self.shownPassword) {
            self.passwordTextField.isSecureTextEntry = false
            self.passwordIconImageView.image = UIImage(named: "ic_eye_on")
        } else {
            self.passwordTextField.isSecureTextEntry = true
            self.passwordIconImageView.image = UIImage(named: "invisible")
        }
    }
   
    private func checkAccountActionStatu() {
        self.createAccountButton.isHidden = self.type != ServerType.KEEPER
        self.forgotPasswordButton.isHidden = self.type != ServerType.KEEPER
    }
    
    // MARK: - 服务器类型选择
    private func showToggleTypeView() {
        if (self.toggleTypeView.isHidden) {
            self.toggleTypeView.alpha = 0
            self.toggleTypeView.isHidden = false
            UIView.animate(withDuration: 0.3) {
                self.toggleTypeView.alpha = 1
            }
        }
        self.serverTypeTextField.resignFirstResponder()
        self.usernameTextField.resignFirstResponder()
        self.passwordTextField.resignFirstResponder()
    }
    private func hiddenToggleTypeView() {
        if (!self.toggleTypeView.isHidden) {
            UIView.animate(withDuration: 0.3) {
                self.toggleTypeView.alpha = 0
            } completion: { (_) in
                self.toggleTypeView.isHidden = true
            }

        }
        self.serverTypeTextField.resignFirstResponder()
        self.usernameTextField.resignFirstResponder()
        self.passwordTextField.resignFirstResponder()
    }
    private func handleToggleTypeView() {
        if (self.toggleTypeView.isHidden) {
            self.showToggleTypeView()
        } else {
            self.hiddenToggleTypeView()
        }
    }
    
    // MARK: - textfield监听
    @objc private func textFieldValueChanged(_ sender: Any) {
        self.checkLoginStatu()
    }
    
    // MARK: - 点击动作

    @IBAction func clickOnToggleTypeAction(_ sender: Any) {
        self.handleToggleTypeView()
    }
    @IBAction func clickOnKeeperType(_ sender: Any) {
        self.hiddenToggleTypeView()
        self.type = ServerType.KEEPER
        self.serverTypeLabel.text = ServerTypeHeler.getServerName(type: self.type)
        self.serverTypeTextField.text = ServerTypeHeler.getServerUrl(type: self.type)
        self.checkLoginStatu()
        self.checkAccountActionStatu()
    }
    @IBAction func clickOnSeaCloudType(_ sender: Any) {
        self.hiddenToggleTypeView()
        self.type = ServerType.SEACLOUD
        self.serverTypeLabel.text = ServerTypeHeler.getServerName(type: self.type)
        self.serverTypeTextField.text = ServerTypeHeler.getServerUrl(type: self.type)
        self.checkLoginStatu()
        self.checkAccountActionStatu()
    }
    @IBAction func clickOnOthersType(_ sender: Any) {
        self.hiddenToggleTypeView()
        self.type = ServerType.OTHERS
        self.serverTypeLabel.text = ServerTypeHeler.getServerName(type: self.type)
        self.serverTypeTextField.text = ServerTypeHeler.getServerUrl(type: self.type)
        self.checkLoginStatu()
        self.checkAccountActionStatu()
    }
    @IBAction func clickOnCreateAccountAction(_ sender: Any) {
        let web = SFSafariViewController(url: URL(string: "https://keeper.mpdl.mpg.de/accounts/register/")!)
        self.present(web, animated: true, completion: nil)
    }
    @IBAction func clickOnForgotPasswordAction(_ sender: Any) {
        let web = SFSafariViewController(url: URL(string: "https://keeper.mpdl.mpg.de/accounts/password/reset/")!)
        self.present(web, animated: true, completion: nil)
    }
    @IBAction func clickOnLoginAction(_ sender: Any) {
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.mode = .indeterminate
        hud.label.text = "LOGIN..."
        self.db.saveMainUrl(url: self.serverTypeTextField.text!)
        self.api.authToken(username: self.usernameTextField.text!, password: self.passwordTextField.text!) { [weak self] () in
            guard let weakSelf = self else {
                return
            }
            hud.hide(animated: true)
            let selectRepoVC = SelectRepoViewController(nibName: "SelectRepoViewController", bundle: nil)
            selectRepoVC.cancelActionBlock = {() in
                weakSelf.db.removeUserToken()
            }
            selectRepoVC.confirmActionBlock = {() in
                if (weakSelf.db.getRepoInfo() != nil) {
                    (UIApplication.shared.delegate as! AppDelegate).setupMainPage()
                }
            }
            weakSelf.present(selectRepoVC, animated: true, completion: nil)
        } failure: {
            hud.label.text = "Incorrect email or password"
            hud.mode = .text
            hud.hide(animated: true, afterDelay: 1)
        }
    }
    @IBAction func clickOnTogglePasswordType(_ sender: Any) {
        self.shownPassword = !self.shownPassword
        self.checkPasswordStatu()
    }
    @IBAction func clickOnCenterView(_ sender: Any) {
        self.hiddenToggleTypeView()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

