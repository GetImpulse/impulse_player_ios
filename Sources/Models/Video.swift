import UIKit

struct Video: Hashable {
    
    let hlsUrl: URL
    let title: String
    let duration: TimeInterval
    var resumeTime: TimeInterval
    
    init(hlsUrl: URL, title: String, duration: TimeInterval, resumeTime: TimeInterval = 0) {
        self.hlsUrl = hlsUrl
        self.title = title
        self.duration = duration
        self.resumeTime = resumeTime
    }
}
