//
//  RepoModel.swift
//  LabCam
//
//  Created by ysq on 2021/2/2.
//

import Foundation
struct RepoModel : Decodable {
    var encrypted: Bool? = false
    let head_commit_id: String?
    let id: String?
    let modifier_contact_email: String?
    let modifier_email: String?
    let modifier_name: String?
    let mtime: Int?
    let mtime_relative: String?
    let name: String?
    let owner: String?
    let owner_contact_email: String?
    let owner_name: String?
    let permission: String?
    let root: String?
    let salt: String?
    let size: Float?
    let size_formatted: String?
    let type: String?
    let version: Int?
    let virtual: Bool?
    let group_name: String?
    let is_admin: Bool?
    let share_type: String?
    var depth: Int?
    var main_repo_name: String?
    var main_repo_id: String?
    var parent_id: String?
    var p: String?
    var sub_repos: Array<RepoModel>?
    var repos_p_ids: Array<String>?
    var is_open: Bool?
}
