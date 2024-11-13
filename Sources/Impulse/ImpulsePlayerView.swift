import UIKit
import Combine

public final class ImpulsePlayerView: UIView {
    
//    private let id: VideoKey = VideoKey.create(playerView: self)
    
    private weak var parent: UIViewController?
    
    public init(parent: UIViewController) {
        self.parent = parent
        super.init(frame: .zero)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var coordinator: PlayerViewControllerCoordinator?
    
    private var shouldPlayAutomatically: Bool = false
    private var seekToTime: TimeInterval?
    private var addedButtons: [(String, PlayerButton)] = []
    
    public weak var delegate: PlayerDelegate? {
        didSet {
            delegate?.onReady(self)
        }
    }
    
    // MARK: - Player Properties
    private var subscribers: Set<AnyCancellable> = []
    @objc dynamic public private(set) var isPlaying: Bool = false
    @objc dynamic public private(set) var state: PlayerState = .loading
    @objc dynamic public private(set) var progress: TimeInterval = 0
    @objc dynamic public private(set) var duration: TimeInterval = 0
    @objc dynamic public private(set) var error: Error?
}

private extension ImpulsePlayerView {
    
    var player: Player? {
        coordinator?.playerViewControllerIfLoaded?.player
    }
}

public extension ImpulsePlayerView {
    
    func load(title: String? = nil, subtitle: String? = nil, url: URL) {
        guard let parent else { return }
        
        let video: Player.Video = .init(
            title: title,
            subtitle: subtitle,
            url: url
        )
        
        // NOTE: Resetting the coordinator if another video was already loaded on it
        if coordinator?.video != video {
            coordinator?.reset()
            coordinator = nil
        } else {
            return
        }
        
        let coord = PlaybackController.shared.coordinator(
            for: .init(
                title: title,
                subtitle: subtitle,
                url: url
            )
        )
        
        coord.delegate = self
        print(coord)
        coord.embedInline(in: parent, container: self)
        
        coord.publisher(for: \.isPlaying)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
            }
            .store(in: &subscribers)
        
        coord.publisher(for: \.state)
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &subscribers)
        
        coord.publisher(for: \.progress)
            .sink { [weak self] progress in
                self?.progress = progress
            }
            .store(in: &subscribers)
        
        coord.publisher(for: \.duration)
            .sink { [weak self] duration in
                self?.duration = duration
            }
            .store(in: &subscribers)
        
        coord.publisher(for: \.error)
            .sink { [weak self] error in
                self?.error = error
            }
            .store(in: &subscribers)
        
        coordinator = coord
        
        // Add buttons added before initialization
        addedButtons.forEach { key, playerButton in
            setButton(key: key, playerButton: playerButton)
        }
        addedButtons = []
    }
    
    func play() {
        if let player {
            player.play()
        } else {
            shouldPlayAutomatically = true
        }
    }
    
    func pause() {
        if let player {
            player.pause()
        } else {
            shouldPlayAutomatically = false
        }
    }
    
    func seek(to seconds: TimeInterval) {
        if let player {
            
        } else {
            seekToTime = seconds
        }
        coordinator?.playerViewControllerIfLoaded?.player.seek(to: seconds)
    }
    
    func setButton(key: String, playerButton: PlayerButton) {
        guard let player else {
            addedButtons.append((key, playerButton))
            return
        }
        
        player.addButton(key: key, playerButton: playerButton)
    }
    
    func removeButton(key: String) {
        guard let player else {
            addedButtons.removeAll(where: { $0.0 == key })
            return
        }
        
        player.removeButton(key: key)
    }
}

extension ImpulsePlayerView: PlayerViewControllerCoordinatorDelegate {
    
    func playerViewControllerCoordinatorDidStartShowingPictureInPicture(_ playerViewControllerCoordinator: PlayerViewControllerCoordinator) {
        PlaybackController.shared.setPictureInPictureCoordinator(playerViewControllerCoordinator)
    }
    
    func playerViewControllerCoordinatorDidStopShowingPictureInPicture(_ playerViewControllerCoordinator: PlayerViewControllerCoordinator) {
        PlaybackController.shared.setPictureInPictureCoordinator(nil)
    }
    
    func onVideoReady() {
        if let seekToTime {
            seek(to: seekToTime)
            self.seekToTime = nil
        }
        
        if shouldPlayAutomatically {
            play()
            shouldPlayAutomatically = false
        }
    }
    
    func onPlay() {
        delegate?.onPlay(self)
    }
    
    func onPause() {
        delegate?.onPause(self)
    }
    
    func onFinish() {
        delegate?.onFinish(self)
    }
    
    func onError(message: String) {
        delegate?.onError(self, message: message)
    }
}