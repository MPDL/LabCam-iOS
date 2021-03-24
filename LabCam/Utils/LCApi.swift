//
//  LCApi.swift
//  LabCam
//
//  Created by ysq on 2021/2/2.
//

import Foundation
import Alamofire

private struct Login: Encodable {
    let username: String
    let password: String
}
private struct UploadLink: Encodable {
    let repoId: String
    let p: String
}
private struct ReposDir: Encodable {
    let p: String
    let t: String // d
}

private enum LCAPIPATH {
    case AUTHTOKEN
    case REPOS
    case REPODIR
    case UPLOADLINK
    func getPathText(param: Dictionary<String,String>? = nil) -> String {
        switch self {
        case .AUTHTOKEN:
            return "api2/auth-token/"
        case .REPOS:
            return "api2/repos/"
        case .REPODIR:
            if (param != nil && param!["reposId"] != nil) {
                return "api2/repos/\(param!["reposId"]!)/dir/"
            }
            return ""
        case .UPLOADLINK:
            if (param != nil && param!["reposId"] != nil) {
                return "api2/repos/\(param!["reposId"]!)/upload-link/"
            }
            return ""
        }
    }
}

class LCApi {
    private let db = DatabaseUtil()
    private func getFullUrl(apiPath: String) -> String {
        return self.db.getMainUrl() + "/" + apiPath
    }
    public func authToken(username: String, password: String, success: (() -> Void)? = nil, failure: (() -> Void)? = nil) {
        let login = Login(username: username, password: password)
        AF.request(self.getFullUrl(apiPath: LCAPIPATH.AUTHTOKEN.getPathText()), method: .post, parameters: login, encoder: JSONParameterEncoder.default).responseDecodable { (response: AFDataResponse<UserModel>) in
            switch response.result {
            case .success(let user):
                self.db.saveUserToken(token: user.token)
                success?()
            case .failure(let error):
                print(error)
                failure?()
            }
        }
    }
    public func getRepos(success: ((Array<RepoModel>) -> Void)? = nil, failure: (() -> Void)? = nil) {
        AF.request(self.getFullUrl(apiPath: LCAPIPATH.REPOS.getPathText()), method: .get, headers: HTTPHeaders([
            "Authorization": "Token " + (self.db.getUserToken() ?? "")
        ])).responseDecodable { (response: AFDataResponse<Array<RepoModel>>) in
            switch response.result {
            case .success(var repos):
                repos = repos.filter { (v) -> Bool in
                    let hide = v.encrypted! || v.permission! != "rw"
                    return !hide
                }
                repos = repos.map { (v) -> RepoModel in
                    var r = v
                    r.depth = 0
                    r.sub_repos = []
                    r.p = "/"
                    r.parent_id = ""
                    r.is_open = false
                    r.main_repo_id = r.id ?? ""
                    r.main_repo_name = v.name ?? ""
                    r.repos_p_ids = [r.id ?? ""]
                    return r
                }
                var repoIds: Array<String> = []
                var returnRepos: Array<RepoModel> = []
                 for repo in repos {
                    if (!repoIds.contains(repo.name ?? "")) {
                        repoIds.append(repo.name ?? "")
                        returnRepos.append(repo)
                    }
                }
                success?(returnRepos)
            case .failure(let error):
                failure?()
                print(error)
            }
        }
    }
    public func getReposDir(reposId: String, reposName: String , p: String, repos_p_ids: Array<String>? = [], depth: Int, success: ((Array<RepoModel>) -> Void)? = nil, failure: (() -> Void)? = nil) {
        let reposDir = ReposDir(p: p, t: "d")
        AF.request(self.getFullUrl(apiPath: LCAPIPATH.REPODIR.getPathText(param: [
            "reposId": reposId
        ])), method: .get, parameters: reposDir, encoder: URLEncodedFormParameterEncoder.default, headers: HTTPHeaders([
            "Authorization": "Token " + (self.db.getUserToken() ?? "")
        ]))
        .responseDecodable { (response: AFDataResponse<Array<RepoModel>>) in
            switch response.result {
            case .success(var repos):
                print(repos)
                repos = repos.filter { (v) -> Bool in
                    let hide = v.permission == "r" || (v.encrypted != nil && (v.encrypted! || (!v.encrypted! && v.permission! == "r")))
                    return !hide
                }
                repos = repos.map { (v) -> RepoModel in
                    var r = v
                    r.depth = depth + 1
                    r.sub_repos = []
                    r.p = p + v.name! + "/"
                    r.parent_id = reposId
                    r.is_open = false
                    r.main_repo_id = reposId
                    r.main_repo_name = reposName
                    r.repos_p_ids = repos_p_ids
                    r.repos_p_ids?.append(r.id ?? "")
                    return r
                }
                success?(repos)
            case .failure(let error):
                print(error)
                failure?()
            }
        }
    }
    public func getUploadLinkWithRepoInfo(repoId: String, p: String, success: ((String) -> Void)? = nil, failure: ((Bool) -> Void)? = nil) {
        let uploadLink = UploadLink(repoId: repoId, p: p)
        AF.request(self.getFullUrl(apiPath: LCAPIPATH.UPLOADLINK.getPathText(param: [
            "reposId": repoId,
        ])), method: .get, parameters: uploadLink, encoder: URLEncodedFormParameterEncoder.default, headers: HTTPHeaders([
            "Authorization": "Token " + (self.db.getUserToken() ?? "")
        ])).responseJSON { (response) in
            switch response.result {
            case .success(let result):
                if let r = result as? String {
                    success?(r)
                } else {
                    failure?(true)
                }
            case .failure(let error):
                print(error)
                failure?(false)
            }
        }
    }
    public func uploadImage(uploadLink: String, parent_dir: String, imageData: Data, imageName: String, success: (() -> Void)? = nil, failure: (() -> Void)? = nil) {
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(imageData, withName: "file", fileName: imageName, mimeType: "image/jpeg")
            multipartFormData.append(Data("1".utf8), withName: "replace")
            multipartFormData.append(Data(parent_dir.utf8), withName: "parent_dir")
        }, to: uploadLink, headers: HTTPHeaders([
            "Authorization": "Token " + (self.db.getUserToken() ?? "")
        ]))
        .uploadProgress(closure: { (progress) in
            print("upload progress: \(progress.fractionCompleted)")
        })
        .response(completionHandler: { (response) in
            print(response)
            switch response.result {
            case .success(let result):
                success?()
            case .failure(let error):
                failure?()
            }
        })
    }
    public func uploadFile(uploadLink: String, parent_dir: String, fileData: Data, fileName: String, success: (() -> Void)? = nil, failure: (() -> Void)? = nil) {
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(fileData, withName: "file", fileName: fileName, mimeType: "text/markdown")
            multipartFormData.append(Data("1".utf8), withName: "replace")
            multipartFormData.append(Data(parent_dir.utf8), withName: "parent_dir")
        }, to: uploadLink, headers: HTTPHeaders([
            "Authorization": "Token " + (self.db.getUserToken() ?? "")
        ]))
        .uploadProgress(closure: { (progress) in
            print("upload progress: \(progress.fractionCompleted)")
        })
        .response(completionHandler: { (response) in
            print(response)
            switch response.result {
            case .success(let result):
                print(result ?? "")
                success?()
            case .failure(let error):
                print(error)
                failure?()
            }
        })
    }
    
}
