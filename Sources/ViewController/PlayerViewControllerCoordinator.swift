import AVKit
import Combine

@MainActor
protocol PlayerViewControllerCoordinatorDelegate: AnyObject {
    func playerViewControllerCoordinatorDidStartShowingPictureInPicture(_ playerViewControllerCoordinator: PlayerViewControllerCoordinator)
    func playerViewControllerCoordinatorDidStopShowingPictureInPicture(_ playerViewControllerCoordinator: PlayerViewControllerCoordinator)
    
    // MARK: Player events
    func onVideoReady()
    func onPlay()
    func onPause()
    func onFinish()
    func onError(message: String)
}

@MainActor
class PlayerViewControllerCoordinator: NSObject {
    
    // MARK: - Initialization
    let video: Player.Video
    
    init(video: Player.Video) {
        self.video = video
        super.init()
    }
    
    // MARK: - Properties
    weak var delegate: PlayerViewControllerCoordinatorDelegate?
    weak var parent: UIViewController?
    weak var containerView: UIView?
    
    // MARK: - Player Properties
    private var subscribers: Set<AnyCancellable> = []
    @objc dynamic var isPlaying: Bool = false
    @objc dynamic var state: PlayerState = .loading
    @objc dynamic var progress: TimeInterval = 0
    @objc dynamic var duration: TimeInterval = 0
    @objc dynamic var error: Error?
    
    private(set) var status: Status = [] {
        didSet {
            if !oldValue.contains(.pictureInPictureActive) && status.contains(.pictureInPictureActive) {
                delegate?.playerViewControllerCoordinatorDidStartShowingPictureInPicture(self)
            }
            
            if oldValue.contains(.pictureInPictureActive) && !status.contains(.pictureInPictureActive) {
                delegate?.playerViewControllerCoordinatorDidStopShowingPictureInPicture(self)
            }
            
            if oldValue.isBeingShown && !status.isBeingShown {
                playerViewControllerIfLoaded?.reset()
                playerViewControllerIfLoaded = nil
            }
        }
    }
    
    private(set) var playerViewControllerIfLoaded: PlayerViewController? {
        didSet {
            guard playerViewControllerIfLoaded != oldValue else { return }
            
            if oldValue?.delegate === self {
                oldValue?.delegate = nil
            }
            
            if oldValue?.hasContent(fromVideo: video) == true {
                oldValue?.reset()
            }
            
            status = []
            
            // 2) Set up the new playerViewController.
            if let playerViewController = playerViewControllerIfLoaded {
                playerViewController.delegate = self
                
                // NOTE: Setting up subscriptions to assign the observable properties to the video container
                subscribers = []
                
                playerViewController.publisher(for: \.isPlaying)
                    .assign(to: \.isPlaying, on: self)
                    .store(in: &subscribers)
                
                playerViewController.publisher(for: \.state)
                    .assign(to: \.state, on: self)
                    .store(in: &subscribers)
                
                playerViewController.publisher(for: \.progress)
                    .assign(to: \.progress, on: self)
                    .store(in: &subscribers)
                
                playerViewController.publisher(for: \.duration)
                    .assign(to: \.duration, on: self)
                    .store(in: &subscribers)
                
                playerViewController.publisher(for: \.error)
                    .assign(to: \.error, on: self)
                    .store(in: &subscribers)
            }
        }
    }
    
    func reset() {
        removeFromParentIfNeeded()
        subscribers = []
    }
}

// Utility functions for some common UIKit tasks that the coordinator manages.
extension PlayerViewControllerCoordinator {
    
    func presentFullScreen(from presentingViewController: UIViewController) {
        self.parent = presentingViewController
        guard !status.contains(.linkedFullScreenActive) else { return }
        removeFromParentIfNeeded()
        loadPlayerViewControllerIfNeeded(isEmbedded: false)
        guard let playerViewController = playerViewControllerIfLoaded else { return }
        status.insert(.linkedFullScreenActive)
        playerViewController.player.isEmbedded = false
        presentingViewController.present(playerViewController, animated: true) {
            playerViewController.player.play()
        }
    }
    
    func embedInline(in parent: UIViewController, container: UIView) {
        self.parent = parent
        self.containerView = container
        loadPlayerViewControllerIfNeeded(isEmbedded: true)
        guard let playerViewController = playerViewControllerIfLoaded, playerViewController.parent != parent else { return }
        removeFromParentIfNeeded()
        status.insert(.embeddedInline)
        playerViewController.player.isEmbedded = true
        parent.addChild(playerViewController)
        
        UIView.performWithoutAnimation {
            container.addSubview(playerViewController.view)
            playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                playerViewController.view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                playerViewController.view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                playerViewController.view.widthAnchor.constraint(equalTo: container.widthAnchor),
                playerViewController.view.heightAnchor.constraint(equalTo: container.heightAnchor)
            ])
            playerViewController.view.layoutIfNeeded()
        }
        
        playerViewController.didMove(toParent: parent)
    }
    
    func restoreFullScreen(from presentingViewController: UIViewController, completion: @escaping () -> Void) {
        guard let playerViewController = playerViewControllerIfLoaded,
              status.contains(.pictureInPictureActive)
            else {
                completion()
                return
        }
        
        if playerViewController.player.isEmbedded == true {
            guard !status.contains(.fullScreenActive) else {
                completion()
                return
            }
            
            playerViewController.view.translatesAutoresizingMaskIntoConstraints = true
            playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleWidth]
            // NOTE: Needed to display close item
            playerViewController.player.isFullScreen = true
            status.insert(.fullScreenActive)
            presentingViewController.present(playerViewController, animated: true, completion: completion)
        } else {
            guard !status.contains(.linkedFullScreenActive) else {
                completion()
                return
            }
            
            // NOTE: Needed to display close item
            status.insert(.linkedFullScreenActive)
            presentingViewController.present(playerViewController, animated: true, completion: completion)
        }
        
    }
    
    // Dismiss any active player view controllers before restoring the interface from Picture in Picture mode.
    func dismiss(completion: @escaping () -> Void) {
        playerViewControllerIfLoaded?.dismiss(animated: true) {
            completion()
            self.status.remove(.fullScreenActive)
            self.status.remove(.linkedFullScreenActive)
        }
    }
    
    // Removes the playerViewController from its container, and updates the status accordingly.
    func removeFromParentIfNeeded() {
        if status.contains(.embeddedInline) {
            playerViewControllerIfLoaded?.willMove(toParent: nil)
            playerViewControllerIfLoaded?.view.removeFromSuperview()
            playerViewControllerIfLoaded?.removeFromParent()
            playerViewControllerIfLoaded?.view.translatesAutoresizingMaskIntoConstraints = true
            playerViewControllerIfLoaded?.view.autoresizingMask = [.flexibleWidth, .flexibleWidth]
            status.remove(.embeddedInline)
        }
    }
}

extension PlayerViewControllerCoordinator: ImpulsePlayerViewControllerDelegate {
    
    func onDidDisappear() {
        reset()
    }
    
    func onDismissPressed() {
        status.remove(.linkedFullScreenActive)
        parent?.dismiss(animated: true)
    }
    
    func fullScreenDidBecomeActive() {
        guard let playerViewController = playerViewControllerIfLoaded, !status.contains(.fullScreenActive) else { return }
        status.insert(.fullScreenActive)
        removeFromParentIfNeeded()
        
        parent?.present(playerViewController, animated: true)
    }
    
    func fullScreenDidBecomeInactive() {
        guard let playerViewController = playerViewControllerIfLoaded, status.contains(.fullScreenActive) else { return }
        playerViewController.dismiss(animated: true) { [weak self] in
            if let parent = self?.parent, let containerView = self?.containerView {
                self?.embedInline(in: parent, container: containerView)
            }
            
            self?.status.remove(.fullScreenActive)
        }
    }
    
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: PlayerViewController) {
        status.insert(.pictureInPictureActive)
    }
    
    func playerViewController(_ playerViewController: PlayerViewController, failedToStartPictureInPictureWithError error: Error) {
        status.remove(.pictureInPictureActive)
    }
    
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: PlayerViewController) {
        status.remove(.pictureInPictureActive)
    }
    
    func playerViewController(_ playerViewController: PlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        if playerViewControllerIfLoaded?.parent == nil {
            completionHandler(false)
        } else {
            completionHandler(true)
        }
    }
    
    func onVideoReady() {
        delegate?.onVideoReady()
    }
    
    func onPlay() {
        delegate?.onPlay()
    }
    
    func onPause() {
        delegate?.onPause()
    }
    
    func onFinish() {
        delegate?.onFinish()
    }
    
    func onError(message: String) {
        delegate?.onError(message: message)
    }
    
    func parentIsBeingDismissed() -> Bool {
        parent?.isBeingDismissed ?? true
    }
}

extension PlayerViewControllerCoordinator {
    
    private func loadPlayerViewControllerIfNeeded(isEmbedded: Bool) {
        if playerViewControllerIfLoaded == nil {
            playerViewControllerIfLoaded = PlayerViewController(isEmbedded: isEmbedded)
            playerViewControllerIfLoaded?.player.load(video: video)
        }
    }
}

extension PlayerViewControllerCoordinator {
    
    struct Status: OptionSet {
        
        let rawValue: Int
        
        static let embeddedInline = Status(rawValue: 1 << 0)
        static let fullScreenActive = Status(rawValue: 1 << 1)
        static let linkedFullScreenActive = Status(rawValue: 1 << 2)
        static let pictureInPictureActive = Status(rawValue: 1 << 3)
        
        static let descriptions: [(Status, String)] = [
            (.embeddedInline, "Embedded Inline"),
            (.fullScreenActive, "Full Screen Active"),
            (.linkedFullScreenActive, "Linked Full Screen Active"),
            (.pictureInPictureActive, "Picture In Picture Active")
        ]
        
        var isBeingShown: Bool {
            return !intersection([.embeddedInline, .pictureInPictureActive, .fullScreenActive, .linkedFullScreenActive]).isEmpty
        }
    }
}

private extension PlayerViewController {
    
    func hasContent(fromVideo video: Player.Video) -> Bool {
        let url = (player.currentItem?.asset as? AVURLAsset)?.url
        return url == video.url
    }
}
