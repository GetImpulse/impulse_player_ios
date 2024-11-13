struct VideoQuality: CustomStringConvertible {
    
    let bitrate: Double
    let resolution: String

    var definition: Definition {
        switch resolution {
        case Self.automaticResolution: .auto
        case "480p": .sd
        case "720p": .hd
        case "1080p": .fhd
        case "2160p": ._2k
        case "4320p": ._4k
        default: .custom(quality: resolution)
        }
    }
    
    var description: String {
        return resolution
    }
    
    static let header: String = .library(for: "quality_title")
    
    static let automaticResolution: String = .library(for: "quality_automatic")
    static let automatic: Self = VideoQuality(bitrate: 0, resolution: automaticResolution)
}

extension VideoQuality {
    
    enum Definition {
        case auto
        case sd
        case hq
        case hd
        case fhd
        case _2k
        case _4k
        case custom(quality: String)

        var iconName: String? {
            switch self {
            case .auto: "Video/Quality/auto"
            case .sd: "Video/Quality/sd"
            case .hq: "Video/Quality/highQuality"
            case .hd: "Video/Quality/hd"
            case .fhd: "Video/Quality/full_hd"
            case ._2k: "Video/Quality/2k"
            case ._4k: "Video/Quality/4k"
            case .custom: nil
            }
        }
        
        var buttonText: String? {
            switch self {
            case .auto, .sd, .hq, .hd, .fhd, ._2k, ._4k:
                return nil
            case .custom(let quality):
                return quality
            }
        }
    }
}

extension VideoQuality: Equatable {
    static func == (lhs: VideoQuality, rhs: VideoQuality) -> Bool {
        return lhs.bitrate == rhs.bitrate && rhs.resolution == lhs.resolution
    }
}

/// Extension to provide additional functionalities for arrays of VideoQuality.
extension [VideoQuality] {
    
    /// Sorts the video qualities by bitrate in descending order and inserts an "Auto" option at the beginning.
    mutating func sortAndInsertAutoVideoQualityOption() {
        sort(by: { $0.bitrate >= $1.bitrate })
        insert(.automatic, at: 0)
    }
}
