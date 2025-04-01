import AVKit

extension CMTime {
    
    func toMinutesAndSeconds() -> String {
        let totalSeconds = CMTimeGetSeconds(self)
        if totalSeconds > 0 {
            let minutes = Int(totalSeconds) / 60
            let seconds = Int(totalSeconds) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return "00:00"
        }
    }
}
