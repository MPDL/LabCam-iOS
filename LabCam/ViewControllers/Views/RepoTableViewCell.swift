//
//  RepoTableViewCell.swift
//  LabCam
//
//  Created by ysq on 2021/2/3.
//

import UIKit

class RepoTableViewCell: UITableViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var iconImageViewLeftLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var repoNameLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
        
    public func setupRepoInfo(repo: RepoModel) {
        self.repoNameLabel.text = repo.name!
        let depth = repo.depth ?? 0
        self.iconImageViewLeftLayoutConstraint.constant = CGFloat(15 * (depth + 1))
        if (depth == 0) {
            if (repo.is_open != nil && repo.is_open!) {
                self.iconImageView.image = UIImage(named: "folder")
            } else {
                self.iconImageView.image = UIImage(named: "case")
            }
        } else {
            if (repo.is_open != nil && repo.is_open!) {
                self.iconImageView.image = UIImage(named: "folder_open")
            } else {
                self.iconImageView.image = UIImage(named: "folder_close")
            }
        }
    }
}
