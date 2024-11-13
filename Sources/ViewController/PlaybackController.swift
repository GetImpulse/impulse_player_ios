import UIKit
import AVFoundation

@MainActor
final class PlaybackController: Sendable {
    
    static let shared: PlaybackController = PlaybackController()
    
    private var openPictureInPictureCoordinator: PlayerViewControllerCoordinator?
    
    func coordinator(for video: Player.Video) -> PlayerViewControllerCoordinator {
        // NOTE: Remove the playbackItems and always create a new coordinator. Only keep track of the coordinator that is currently displayed in picture in picture and reference that coordinator to the given video to determine if the same coordinator should be returned for possible recovery from picture in picture.
        if let openPictureInPictureCoordinator, openPictureInPictureCoordinator.video == video {
            return openPictureInPictureCoordinator
        } else {
            return  PlayerViewControllerCoordinator(video: video)
        }
    }
    
    func setPictureInPictureCoordinator(_ coordinator: PlayerViewControllerCoordinator?) {
        openPictureInPictureCoordinator = coordinator
    }
}
