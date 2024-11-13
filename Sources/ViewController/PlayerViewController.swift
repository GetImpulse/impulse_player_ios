import UIKit
import AVFoundation
import Combine

@MainActor
protocol ImpulsePlayerViewControllerDelegate: AnyObject {
    func onDismissPressed()
    func fullScreenDidBecomeActive()
    func fullScreenDidBecomeInactive()
    func onDidDisappear()
    
    // MARK: Picture in Picture interaction
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: PlayerViewController)
    func playerViewController(_ playerViewController: PlayerViewController, failedToStartPictureInPictureWithError error: Error)
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: PlayerViewController)
    func playerViewController(_ playerViewController: PlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void)
    
    // MARK: Player events
    func onVideoReady()
    func onPlay()
    func onPause()
    func onFinish()
    func onError(message: String)
    
    func parentIsBeingDismissed() -> Bool
}

class PlayerViewController: UIViewController {
    
    private let isEmbedded: Bool
    weak var delegate: ImpulsePlayerViewControllerDelegate?
    
    init(isEmbedded: Bool) {
        self.isEmbedded = isEmbedded
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if Bundle.main.getSupportedInterfaceOrientations().contains(.landscapeLeft) || Bundle.main.getSupportedInterfaceOrientations().contains(.landscapeRight) {
            return .landscape
        } else {
            return .all
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if delegate?.parentIsBeingDismissed() ?? true {
            delegate?.onDidDisappear()
        }
    }
    
    lazy var player: Player = Player(isEmbedded: isEmbedded).forAutoLayout()
    
    func loadVideo(_ video: Player.Video) {
        player.load(video: video)
    }
    
    func reset() {
        subscribers = []
        player.stopPlayer()
    }
    
    // MARK: - Player Properties
    private var subscribers: Set<AnyCancellable> = []
    @objc dynamic var isPlaying: Bool = false
    @objc dynamic var state: PlayerState = .loading
    @objc dynamic var progress: TimeInterval = 0
    @objc dynamic var duration: TimeInterval = 0
    @objc dynamic var error: Error?
}

private extension PlayerViewController {
    
    func setup() {
        modalPresentationStyle = .fullScreen
        view.backgroundColor = .black

        setupPlayer()
    }
    
    func setupPlayer() {
        view.addSubview(player)
        NSLayoutConstraint.activate([
            player.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            player.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            player.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            player.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
        ])
        
        player.delegate = self
        
        subscribers = []
        
        player.publisher(for: \.isPlaying)
            .removeDuplicates()
            .assign(to: \.isPlaying, on: self)
            .store(in: &subscribers)
        
        player.publisher(for: \.videoState)
            .removeDuplicates()
            .assign(to: \.state, on: self)
            .store(in: &subscribers)
        
        player.publisher(for: \.progress)
            .removeDuplicates()
            .assign(to: \.progress, on: self)
            .store(in: &subscribers)
        
        player.publisher(for: \.duration)
            .removeDuplicates()
            .assign(to: \.duration, on: self)
            .store(in: &subscribers)
        
        player.publisher(for: \.error)
            .assign(to: \.error, on: self)
            .store(in: &subscribers)
    }
}

extension PlayerViewController: InternalPlayerDelegate {
    
    func onDismissPressed() {
        delegate?.onDismissPressed()
    }
    
    func fullScreenDidBecomeInActive() {
        delegate?.fullScreenDidBecomeInactive()
    }
    
    func fullScreenDidBecomeActive() {
        delegate?.fullScreenDidBecomeActive()
    }
    
    func playerWillStartPictureInPicture() {
        delegate?.playerViewControllerWillStartPictureInPicture(self)
    }
    
    func playerFailedToStartPictureInPictureWithError(_ error: any Error) {
        delegate?.playerViewController(self, failedToStartPictureInPictureWithError: error)
    }
    
    func playerDidStopPictureInPicture() {
        delegate?.playerViewControllerDidStopPictureInPicture(self)
    }
    
    func player(_ player: Player, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        delegate?.playerViewController(self, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: completionHandler)
    }
    
    @available(iOS 15.0, *)
    func onRateButtonPressed() {
        let pickerTableView = PickerTableView(header: Speed.header, items: Speed.allCases, currentlySelectedItem: player.rate)
        pickerTableView.delegate = self
        pickerTableView.modalPresentationStyle = .pageSheet
        if let sheet = pickerTableView.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.preferredCornerRadius = 16.0
            sheet.prefersGrabberVisible = true
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(pickerTableView, animated: true, completion: nil)
    }
    
    @available(iOS 15.0, *)
    func onQualityButtonPressed(qualities: [VideoQuality]) {
        let pickerTableView = PickerTableView(header: VideoQuality.header, items: qualities, currentlySelectedItem: player.quality)
        pickerTableView.delegate = self
        pickerTableView.modalPresentationStyle = .pageSheet
        if let sheet = pickerTableView.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.preferredCornerRadius = 16.0
            sheet.prefersGrabberVisible = true
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(pickerTableView, animated: true, completion: nil)
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
}

extension PlayerViewController: PickerTableViewDelegate {
    
    func selectedItemInPickerView<T>(_ pickerView: PickerTableView<T>, item: T) where T : CustomStringConvertible {
        switch item {
        case let rate as Speed:
            player.rate = rate
        case let quality as VideoQuality:
            player.quality = quality
        default:
            break
        }
    }
}
