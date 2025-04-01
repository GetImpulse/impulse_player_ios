import Foundation

class Settings {
    
    @MainActor static var videos: [Video] = [
        Video(
            title: "Big Buck Bunny",
            url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!
        ),
        Video(
            title: "Sintel",
            url: URL(string: "https://origin.broadpeak.io/bpk-vod/voddemo/hlsv4/5min/sintel/index.m3u8")!
        ),
        Video(
            title: "Tears of Steel",
            url: URL(string: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8")!
        )
    ]
}
