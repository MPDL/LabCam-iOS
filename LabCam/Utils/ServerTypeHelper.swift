//
//  ServerTypeHelper.swift
//  LabCam
//
//  Created by ysq on 2021/1/31.
//

import Foundation

public enum ServerType {
    case KEEPER
    case SEACLOUD
    case OTHERS
}

class ServerTypeHeler {
    public static func getServerUrl(type: ServerType) -> String {
        switch type {
        case .KEEPER:
            return "https://keeper.mpdl.mpg.de"
        case .SEACLOUD:
            return "https://seacloud.cc"
        default:
            return "https://"
        }
    }
    public static func getServerNameWithUrl(url: String) -> String {
        if (url == self.getServerUrl(type: .KEEPER)) {
            return self.getServerName(type: .KEEPER)
        } else if (url == self.getServerUrl(type: .SEACLOUD)) {
            return self.getServerName(type: .SEACLOUD)
        }
        return self.getServerName(type: .OTHERS)
    }
    public static func getServerName(type: ServerType) -> String {
        switch type {
        case .KEEPER:
            return "KEEPER"
        case .SEACLOUD:
            return "SeaCloud.cc"
        default:
            return "Others"
        }
    }
}
