import UIKit
import ImpulsePlayer

class VideoCell: UITableViewCell {
    
    var playerView: ImpulsePlayerView?
    
    func load(video: Video, seekTo: TimeInterval? = nil, parent: UIViewController) {
        if playerView == nil {
            let impulsePlayerView = ImpulsePlayerView(parent: parent)
            impulsePlayerView.translatesAutoresizingMaskIntoConstraints = false
            impulsePlayerView.heightAnchor.constraint(equalTo: impulsePlayerView.widthAnchor, multiplier: 9.0/16.0).isActive = true
            self.contentView.addSubview(impulsePlayerView)
            
            self.contentView.widthAnchor.constraint(equalTo: impulsePlayerView.widthAnchor, multiplier: 1.0).isActive = true
            self.contentView.heightAnchor.constraint(equalTo: impulsePlayerView.heightAnchor, multiplier: 1.0).isActive = true
            
            self.playerView = impulsePlayerView
        }
        
        self.playerView?.load(
            url: video.url,
            title: video.title,
            subtitle: "A video subtitle"
        )
        
        if let seekTo {
            self.playerView?.seek(to: seekTo)
        }
    }
}
