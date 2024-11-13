import UIKit

enum Speed {
    case _0_25
    case _0_5
    case _0_75
    case _1
    case _1_25
    case _1_5
    case _1_75
    case _2
    
    static let header: String = .library(for: "controls_speed")
    
    var speed: Float {
        switch self {
        case ._0_25: 0.25
        case ._0_5: 0.5
        case ._0_75: 0.75
        case ._1: 1
        case ._1_25: 1.25
        case ._1_5: 1.5
        case ._1_75: 1.75
        case ._2: 2
        }
    }
    
    var iconName: String {
        switch self {
        case ._0_25: "Video/Rate/0_25x"
        case ._0_5: "Video/Rate/0_5x"
        case ._0_75: "Video/Rate/0_75x"
        case ._1: "Video/Rate/1x"
        case ._1_25: "Video/Rate/1_25x"
        case ._1_5: "Video/Rate/1_5x"
        case ._1_75: "Video/Rate/1_75x"
        case ._2: "Video/Rate/2x"
        }
    }
}

extension Speed: CaseIterable {}

extension Speed: CustomStringConvertible {
    var description: String {
        switch self {
        case ._0_25: "0.25x"
        case ._0_5: "0.5x"
        case ._0_75: "0.75x"
        case ._1: "1x"
        case ._1_25: "1.25x"
        case ._1_5: "1.5x"
        case ._1_75: "1.75x"
        case ._2: "2x"
        }
    }
}
