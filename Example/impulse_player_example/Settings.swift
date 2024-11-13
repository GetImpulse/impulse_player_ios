import Foundation

class Settings {
    
    static var videos: [Video] = [
        Video(
            title: "Big Buck Bunny",
            url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!
        ),
        Video(
            title: "Big Buck Bunny 480p",
            url: URL(string: "https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8")!
        ),
    ]
}
