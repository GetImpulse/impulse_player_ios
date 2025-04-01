import UIKit
import GoogleCast

enum RemoteDevice {
    case thisDevice
    case airplay
    case cast(device: GCKDevice)
    
    static let header: String = .library(for: "remote_device_title")
    
    var iconName: String {
        switch self {
        case .thisDevice: "Video/RemoteDevice/Phone"
        case .airplay: "Video/RemoteDevice/Airplay"
        case .cast: "Video/RemoteDevice/Cast"
        }
    }
}

extension RemoteDevice: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .thisDevice: .library(for: "remote_device_disconnect")
        case .airplay: .library(for: "remote_device_airplay")
        case .cast(let device): device.friendlyName ?? .library(for: "remote_device_unknown")
        }
    }
}

extension RemoteDevice: Equatable {}
