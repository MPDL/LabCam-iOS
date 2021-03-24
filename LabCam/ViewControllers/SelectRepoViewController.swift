//
//  SelectRepoViewController.swift
//  LabCam
//
//  Created by ysq on 2021/2/3.
//

import UIKit

class SelectRepoViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var reposMainView: UIView!
    @IBOutlet weak var reposTitleView: UIView!
    @IBOutlet weak var reposTitleLabel: UILabel!
    @IBOutlet weak var reposTableView: UITableView!
    var cancelActionBlock: (() -> Void)?
    var confirmActionBlock: (() -> Void)?
    private let api = LCApi()
    private let db = DatabaseUtil()
    private var repos: Array<RepoModel> = []
    private var selectedRepo: RepoModel?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setup()
        self.loadData()
        self.updateTitle()
    }
    
    private func setup() {
        self.reposTitleLabel.text = ServerTypeHeler.getServerNameWithUrl(url: self.db.getMainUrl())
        self.reposMainView.layer.cornerRadius = 8
        self.reposMainView.clipsToBounds = true
        self.reposTableView.dataSource = self
        self.reposTableView.delegate = self
        let v = UIView(frame: CGRect.zero)
        v.backgroundColor = .white
        self.reposTableView.tableFooterView = v
        self.reposTableView.register(UINib(nibName: "RepoTableViewCell", bundle: nil), forCellReuseIdentifier: "RepoTableViewCell")
    }
    
    private func updateTitle() {
        if (self.selectedRepo == nil) {
            if let repoInfo = self.db.getRepoInfo() {
                self.reposTitleLabel.text = repoInfo["mainRepoName"]! + repoInfo["p"]!
            } else {
                self.reposTitleLabel.text = ServerTypeHeler.getServerNameWithUrl(url: self.db.getMainUrl())
            }
        } else {
            self.reposTitleLabel.text = (self.selectedRepo!.main_repo_name! + self.selectedRepo!.p!)
        }
    }
    
    private func loadData() {
        self.api.getRepos { [weak self] (repos) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.repos = repos
            weakSelf.handleAutoOpenRepo()
        } failure: {
            print("error")
        }
    }
    
    private func handleAutoOpenRepo() {
        if let repoInfo = self.db.getRepoInfo() {
            let p = repoInfo["p"]!
            let p_arr = p.components(separatedBy: "/")
            if (p == "" || p == "/" || repoInfo["mainRepoName"] == "" || repoInfo["mainRepoName"] == "/") {
                self.reposTableView.reloadData()
                return
            }
            var reload = true
            for repo in self.repos {
                if (repo.name == repoInfo["mainRepoName"]) {
                    self.api.getReposDir(reposId: repo.main_repo_id!, reposName: repo.main_repo_name!, p: repo.p ?? "/", repos_p_ids: repo.repos_p_ids ?? [], depth: repo.depth!) { [weak self] (repos) in
                        guard let weakSelf = self else {
                            return
                        }
                        if (repos.count == 0) {
                            weakSelf.reposTableView.reloadData()
                            return
                        }
                        weakSelf.repos = weakSelf.updateRepo(repo: repo, repos: weakSelf.repos, sub_repos: repos)
                        weakSelf.handleAutoOpenSubRepo(sub_repos: repos, p_arr: p_arr, index: 0)
                    } failure: { [weak self] () in
                        guard let weakSelf = self else {
                            return
                        }
                        weakSelf.reposTableView.reloadData()
                    }
                    reload = false
                    break
                }
            }
            if (reload) {
                self.reposTableView.reloadData()
            }
        } else {
            self.reposTableView.reloadData()
        }
    }
    
    private func handleAutoOpenSubRepo(sub_repos: [RepoModel], p_arr: [String], index: Int) {
        if (index >= p_arr.count) {
            self.reposTableView.reloadData()
            return
        }
        if (p_arr[index] == "") {
            self.handleAutoOpenSubRepo(sub_repos: sub_repos, p_arr: p_arr, index: index + 1)
            return
        }
        var reload = true
        for repo in sub_repos {
            if (repo.name == p_arr[index]) {
                self.api.getReposDir(reposId: repo.main_repo_id!, reposName: repo.main_repo_name!, p: repo.p ?? "/", repos_p_ids: repo.repos_p_ids ?? [], depth: repo.depth!) { [weak self] (repos) in
                    guard let weakSelf = self else {
                        return
                    }
                    if (repos.count == 0) {
                        weakSelf.reposTableView.reloadData()
                        return
                    }
                    weakSelf.repos = weakSelf.updateRepo(repo: repo, repos: weakSelf.repos, sub_repos: repos)
                    weakSelf.handleAutoOpenSubRepo(sub_repos: repos, p_arr: p_arr, index: index + 1)
                } failure: { [weak self] () in
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.handleAutoOpenSubRepo(sub_repos: sub_repos, p_arr: p_arr, index: index + 1)
                }
                reload = false
                break
            }
        }
        if (reload) {
            self.handleAutoOpenSubRepo(sub_repos: sub_repos, p_arr: p_arr, index: index + 1)
        }
    }
    
    // MARK: - get repo
    
    private func getReposCount(repos: Array<RepoModel>) -> Int {
        var count = 0
        for repo in repos {
            count = count + 1
            if (repo.is_open!) {
                count = count + self.getReposCount(repos: repo.sub_repos ?? [])
            }
        }
        return count
    }
    private func getRepo(repos: Array<RepoModel>, indexPath: IndexPath, beginRow: Int = 0) -> (Int, RepoModel?) {
        var row = beginRow
        var result: RepoModel?
        for repo in repos {
            if (indexPath.row == row) {
                result = repo
                return (row, result)
            }
            if (repo.is_open!) {
                if (repo.sub_repos != nil && repo.sub_repos!.count > 0) {
                    (row, result) = self.getRepo(repos: repo.sub_repos ?? [], indexPath: indexPath, beginRow: row + 1)
                    if (result != nil) {
                        return (row, result)
                    }
                } else {
                    row = row + 1
                }
            } else {
                row = row + 1
            }
        }
        return (row, result)
    }
    
    
    private func updateRepo(repo: RepoModel, repos: Array<RepoModel>, sub_repos: Array<RepoModel>, is_open: Bool? = true) -> Array<RepoModel> {
        let result = repos.map({ (v) -> RepoModel in
            var v1 = v
            if (v1.id == repo.id) {
                v1.is_open = is_open!
                v1.sub_repos = sub_repos
                return v1
            }
            else if (v1.sub_repos != nil && v1.sub_repos!.count > 0) {
                v1.sub_repos = self.updateRepo(repo: repo, repos: v1.sub_repos!, sub_repos: sub_repos, is_open: is_open)
            }
            return v1
        })
        return result
    }
    
    private func closeOtherRepos(repo: RepoModel, repos: Array<RepoModel>) -> Array<RepoModel> {
        let result = repos.map({ (v) -> RepoModel in
            var v1 = v
            if (v1.id == repo.id) {
                
            } else {
                if ((repo.repos_p_ids ?? []).contains(v1.id ?? "")) {
                    
                } else {
                    v1.is_open = false
                }
                if (v1.sub_repos != nil && v1.sub_repos!.count > 0) {
                    v1.sub_repos = self.closeOtherRepos(repo: repo, repos: v1.sub_repos!)
                }
            }
            return v1
        })
        return result
    }
    
    // MARK: - tableview
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.getReposCount(repos: self.repos)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 45
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: RepoTableViewCell? = tableView.dequeueReusableCell(withIdentifier: "RepoTableViewCell") as? RepoTableViewCell
        if (cell == nil) {
            cell = RepoTableViewCell(style: .default, reuseIdentifier: "cellForRowAt")
        }
        let (_, repo) = self.getRepo(repos: self.repos, indexPath: indexPath, beginRow: 0)
        if repo != nil {
            cell?.setupRepoInfo(repo: repo!)
        }
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let (_, r) = self.getRepo(repos: self.repos, indexPath: indexPath, beginRow: 0)
        guard var repo = r else {
            return
        }
        self.repos = self.closeOtherRepos(repo: repo, repos: self.repos)
        self.reposTableView.reloadData()
        self.selectedRepo = repo
        self.updateTitle()
        if (repo.sub_repos!.count > 0) {
            repo.is_open = !repo.is_open!
            self.repos = self.updateRepo(repo: repo, repos: self.repos, sub_repos: repo.sub_repos ?? [], is_open: repo.is_open!)
            self.reposTableView.reloadData()
            return
        }
        self.api.getReposDir(reposId: repo.main_repo_id!, reposName: repo.main_repo_name!, p: repo.p ?? "/", repos_p_ids: repo.repos_p_ids ?? [], depth: repo.depth!) { [weak self] (repos) in
            if (repos.count == 0) {
                return
            }
            guard let weakSelf = self else {
                return
            }
            weakSelf.repos = weakSelf.updateRepo(repo: repo, repos: weakSelf.repos, sub_repos: repos)
            weakSelf.reposTableView.reloadData()
        } failure: {
            print("error")
        }
    }
    
    // MARK: - actions

    @IBAction func clickOnCancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        cancelActionBlock?()
    }
    @IBAction func clickOnConfirmAction(_ sender: Any) {
        if (self.selectedRepo != nil) {
            self.db.saveRepoInfo(repoId: self.selectedRepo!.main_repo_id!, p: self.selectedRepo!.p!, mainRepoName: self.selectedRepo!.main_repo_name!)
        }
        confirmActionBlock?()
    }
}
