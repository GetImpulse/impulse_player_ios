import AVKit
import Combine
import GoogleCast

@MainActor
protocol InternalPlayerDelegate: AnyObject, Sendable {
    func onDismissPressed()
    
    func fullScreenDidBecomeInActive()
    func fullScreenDidBecomeActive()
    
    func playerWillStartPictureInPicture()
    func playerFailedToStartPictureInPictureWithError(_ error: Error)
    func playerDidStopPictureInPicture()
    func player(_ player: Player, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void)
    
    @available(iOS 15.0, *)
    func onRateButtonPressed()
    
    @available(iOS 15.0, *)
    func onQualityButtonPressed(qualities: [VideoQuality])
    
    func onRemoteDeviceButtonPressed()
    
    // MARK: Player actions
    func onVideoReady()
    func onPlay()
    func onPause()
    func onFinish()
    func onError(message: String)
}

class Player: UIView {
    
    enum State {
        case unknown
        case loading
        case readyToPlay
        case error(error: Error?)
    }
    
    // MARK: Player
    private var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            if let newValue {
                setupPlayerObservers(for: newValue)
            }
        }
    }
    
    // MARK: Components
    private var playerLayer: AVPlayerLayer = AVPlayerLayer()
    
    private let standardPlayerOverlayView: StandardPlayerOverlayView = StandardPlayerOverlayView().forAutoLayout()
    private let pictureInPictureOverlayView: UIView = UIView().forAutoLayout()
    private let castOverlayView: CastOverlayView = CastOverlayView().forAutoLayout()
    
    private let loadingActivity: PlayerLoadingView = PlayerLoadingView().forAutoLayout()
    private let playerRetryView: PlayerRetryView = PlayerRetryView().forAutoLayout()
    
    // MARK: DI
    var isEmbedded: Bool {
        didSet {
            standardPlayerOverlayView.setFullScreenButtonVisibility(visible: isEmbedded)
        }
    }
    
    init(isEmbedded: Bool) {
        self.isEmbedded = isEmbedded
        super.init(frame: .zero)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Private Properties
    private let manifestHelper = ManifestHelper()
    private let activityPassthroughSubject = PassthroughSubject<Void, Never>()
    private let buttonSymbolConfig = UIImage.SymbolConfiguration(pointSize: 20.0, weight: .regular, scale: .medium)
    
    private let sessionManager: GCKSessionManager = GCKCastContext.sharedInstance().sessionManager
    private let castMediaController: GCKUIMediaController = GCKUIMediaController()
    
    private var pictureInPictureControllerIfLoaded: AVPictureInPictureController? {
        didSet {
            guard pictureInPictureControllerIfLoaded != oldValue else { return }
            
            if oldValue?.delegate === self {
                oldValue?.delegate = nil
            }
            
            // 2) Set up the new picture in picture controller
            if let pipController = pictureInPictureControllerIfLoaded {
                pipController.delegate = self
                
                // NOTE: Setting up subscriptions to assign the observable properties to the video container
                pictureInPictureViewControllerSubscribers = []
                standardPlayerOverlayView.setPipButtonEnabled(pictureInPictureControllerIfLoaded?.isPictureInPictureActive ?? true)
                pictureInPictureControllerIfLoaded?.publisher(for: \.isPictureInPicturePossible)
                    .removeDuplicates()
                    .receive(on: RunLoop.main)
                    .sink { [weak self] change in
                        self?.standardPlayerOverlayView.setPipButtonEnabled(change)
                    }.store(in: &subscriptions)
            }
        }
    }
    
    private var qualities: [VideoQuality] = [.automatic] {
        didSet {
            if #unavailable(iOS 15.0) {
                standardPlayerOverlayView.setQualityOptions(qualities)
            }
        }
    }
    private var subscriptions: Set<AnyCancellable> = []
    private var playerSubscribers: Set<AnyCancellable> = []
    private var playerItemSubscribers: Set<AnyCancellable> = []
    private var pictureInPictureViewControllerSubscribers: Set<AnyCancellable> = []
    private var timeObserver: Any?
    private var developerButtons: [String: PlayerBarButton] = [:]
    private var itemDidEnd: Bool = false
    private var startedCastingFromThisVideo: Bool = false
    private var stoppedCastingFromThisVideo: Bool = false
    
    private var isSeeking: Bool = false
    private var video: Video?
    private var mediaInformation: GCKMediaInformation?
    
    // Observable properties
    @objc dynamic var isPlaying: Bool = false
    @objc dynamic var videoState: PlayerState = .loading
    @objc dynamic var progress: TimeInterval = 0
    @objc dynamic var duration: TimeInterval = 0
    @objc dynamic var error: Error?
    
    // MARK: Internal Properties
    weak var delegate: InternalPlayerDelegate?
    
    var castEnabled: Bool = true {
        didSet {
            standardPlayerOverlayView.castEnabled = castEnabled
            determineOverlayVisibility()
            
            if oldValue != castEnabled && castEnabled == false {
                stopCastingIfNeeded()
            }
        }
    }
    
    var isFullScreen: Bool = false {
        didSet {
            loadingActivity.size = isFullScreen ? .large : .small
            standardPlayerOverlayView.switchFullScreen(on: isFullScreen)
            
            if isFullScreen {
                delegate?.fullScreenDidBecomeActive()
            } else {
                delegate?.fullScreenDidBecomeInActive()
            }
        }
    }
    
    var rate: Speed = ._1 {
        didSet {
            player?.rate = rate.speed
            standardPlayerOverlayView.setRate(rate)
        }
    }
    
    var quality: VideoQuality = .automatic {
        didSet {
            player?.currentItem?.preferredPeakBitRate = quality.bitrate
            standardPlayerOverlayView.setQuality(quality)
        }
    }
    
    var state: State = .unknown {
        didSet {
            determineOverlayVisibility()
            switch state {
            case .unknown:
                videoState = .loading
            case .loading:
                videoState = .loading
                loadingActivity.startAnimating()
            case .readyToPlay:
                videoState = .ready
                loadingActivity.stopAnimating()
            case .error(let error):
                videoState = .error
                loadingActivity.stopAnimating()
                
                // NOTE: Display the retry view with the found error code
                let code = (error as? NSError)?.code
                playerRetryView.update(code: code)
                
                delegate?.onError(message: error?.localizedDescription ?? "Unknown error")
            }
        }
    }
    
    // MARK: Private Write, Internal Read-Only
    private(set) var timeControlStatus: AVPlayer.TimeControlStatus = .paused {
        didSet {
            NSLog("Time Control Status: \(timeControlStatus)")
            NSLog("Waiting To Play At Specified Rate. Reason: \(player?.reasonForWaitingToPlay.debugDescription ?? "Unknown Reason")")
            if case .error(_) = state {
                return
            }
            
            switch timeControlStatus {
            case .playing:
                state = .readyToPlay
            case .paused:
                state = player?.currentItem?.status == .readyToPlay ? .readyToPlay : .loading
            case .waitingToPlayAtSpecifiedRate:
                break
            @unknown default:
                fatalError("Unknown time control state unhandled")
            }
        }
    }
    
    private(set) var controlType: ControlType = .standard {
        didSet {
            determineOverlayVisibility()
        }
    }
}

extension Player {
    
    enum ControlType {
        case standard
        case pictureInPicture
        case casting
    }
}

extension Player {
    
    // MARK: Internal Read-Only
    var isRemote: Bool {
        return sessionManager.hasConnectedCastSession()
    }
    
    var currentItem: AVPlayerItem? {
        player?.currentItem
    }
    
    // MARK: Internal Functions
    func load(video: Video) {
        self.video = video
        
        loadVideo(video)
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func stopPlayer() {
        player?.pause()
        player = nil
        subscriptions = []
        playerSubscribers = []
        playerItemSubscribers = []
    }
    
    func seek(to seconds: TimeInterval) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1))
    }
    
    func addButton(key: String, playerButton: PlayerButton) {
        removeButton(key: key)
        
        let button = PlayerBarButton().forAutoLayout()
        
        button.setImage(playerButton.icon, for: .normal)
        button.accessibilityLabel = playerButton.title
        
        let action = UIAction { _ in
            playerButton.action()
        }
        button.addAction(action, for: .touchUpInside)
        
        switch playerButton.position {
        case .topEnd:
            standardPlayerOverlayView.addControl(button, position: .topTrailing)
        case .bottomStart:
            standardPlayerOverlayView.addControl(button, position: .bottomBottomLeading)
        case .bottomEnd:
            standardPlayerOverlayView.addControl(button, position: .bottomBottomTrailing)
        }
        
        developerButtons[key] = button
    }
    
    func removeButton(key: String) {
        if let button = developerButtons[key] {
            button.removeFromSuperview()
        }
    }
    
    func connectTo(_ remoteDevice: RemoteDevice) {
        switch remoteDevice {
        case .thisDevice:
            stoppedCastingFromThisVideo = true
            sessionManager.endSessionAndStopCasting(true)
        case .airplay:
            stoppedCastingFromThisVideo = true
            sessionManager.endSessionAndStopCasting(true)
            standardPlayerOverlayView.triggerAirplaySelection()
        case .cast(let device):
            startedCastingFromThisVideo = true
            sessionManager.startSession(with: device)
        }
    }
}

// MARK: - Actions
private extension Player {
    
    func dismiss() {
        activityPassthroughSubject.send()
        if isEmbedded {
            isFullScreen = false
        } else {
            delegate?.onDismissPressed()
        }
    }
    
    @objc func togglePictureInPicture() {
        guard let pictureInPictureControllerIfLoaded else { return }
        if pictureInPictureControllerIfLoaded.isPictureInPictureActive {
            pictureInPictureControllerIfLoaded.stopPictureInPicture()
        } else {
            pictureInPictureControllerIfLoaded.startPictureInPicture()
        }
    }
    
    @objc func showOverlay() {
        activityPassthroughSubject.send()
        UIView.animate(withDuration: 0.5) { [weak self] in
            self?.standardPlayerOverlayView.alpha = 1
        }
    }
    
    @objc func hideOverlay() {
        guard case .readyToPlay = state else { return }
        UIView.animate(withDuration: 0.5) { [weak self] in
            self?.standardPlayerOverlayView.alpha = 0
        }
    }
}

// MARK: - Setup
private extension Player {
    
    func setup() {
        layer.addSublayer(playerLayer)
        
        let showTapGesture = UITapGestureRecognizer(target: self, action: #selector(showOverlay))
        showTapGesture.numberOfTapsRequired = 1
        addGestureRecognizer(showTapGesture)
        
        quality = .automatic
        isFullScreen = false
        
        if ImpulsePlayer.shared.settings.pictureInPictureEnabled {
            loadPictureInPictureControllerIfNeeded()
        }
        
        setupLayout()
        setupObservers()
        
        if sessionManager.hasConnectedSession() {
            switchToRemotePlayback(shouldAutoPlay: false)
        } else if pictureInPictureControllerIfLoaded?.isPictureInPictureActive == true {
            controlType = .pictureInPicture
        } else {
            controlType = .standard
        }
    }
    
    func setupLayout() {
        setupOverlayView()
        setupPictureInPictureOverlayView()
        setupCastOverlayView()
        setupPlayerRetryView()
        
        setupLoadingActivity()
    }
    
    func setupOverlayView() {
        standardPlayerOverlayView.backgroundColor = .black.withAlphaComponent(0.3)
        
        let hideTapGesture = UITapGestureRecognizer(target: self, action: #selector(hideOverlay))
        hideTapGesture.numberOfTapsRequired = 1
        standardPlayerOverlayView.addGestureRecognizer(hideTapGesture)
        
        addSubview(standardPlayerOverlayView)
        NSLayoutConstraint.activate([
            standardPlayerOverlayView.topAnchor.constraint(equalTo: topAnchor),
            standardPlayerOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            standardPlayerOverlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            standardPlayerOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
        
        standardPlayerOverlayView.setFullScreenButtonVisibility(visible: isEmbedded)
        standardPlayerOverlayView.delegate = self
    }
    
    // MARK: Picture In Picture OverlayView
    func setupPictureInPictureOverlayView() {
        pictureInPictureOverlayView.backgroundColor = .black.withAlphaComponent(0.8)
        pictureInPictureOverlayView.isHidden = pictureInPictureControllerIfLoaded?.isPictureInPictureActive != true
        
        addSubview(pictureInPictureOverlayView)
        NSLayoutConstraint.activate([
            pictureInPictureOverlayView.topAnchor.constraint(equalTo: topAnchor),
            pictureInPictureOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pictureInPictureOverlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pictureInPictureOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
        
        let centerStackView = UIStackView().forAutoLayout()
        centerStackView.axis = .vertical
        centerStackView.spacing = 8.0
        centerStackView.alignment = .center
        pictureInPictureOverlayView.addSubview(centerStackView)
        NSLayoutConstraint.activate([
            centerStackView.centerXAnchor.constraint(equalTo: pictureInPictureOverlayView.centerXAnchor),
            centerStackView.centerYAnchor.constraint(equalTo: pictureInPictureOverlayView.centerYAnchor),
            centerStackView.widthAnchor.constraint(equalTo: pictureInPictureOverlayView.widthAnchor, constant: -24 * 2),
            centerStackView.topAnchor.constraint(greaterThanOrEqualTo: pictureInPictureOverlayView.topAnchor, constant: 24.0),
            pictureInPictureOverlayView.bottomAnchor.constraint(greaterThanOrEqualTo: centerStackView.bottomAnchor, constant: 24.0)
        ])
        
        let exitButton = UIButton(type: .custom).forAutoLayout()
        exitButton.setImage(.library(named: "Video/PictureInPicture/Exit"), for: .normal)
        exitButton.tintColor = .white
        exitButton.imageView?.contentMode = .scaleAspectFit
        exitButton.addTarget(self, action: #selector(togglePictureInPicture), for: .touchUpInside)
        centerStackView.addArrangedSubview(exitButton)
        exitButton.heightAnchor.constraint(equalToConstant: 32.0).isActive = true
        exitButton.widthAnchor.constraint(equalTo: heightAnchor).isActive = true
        
        let exitLabel = UILabel().forAutoLayout()
        exitLabel.font = ImpulsePlayer.shared.appearance.p2.font
        exitLabel.textColor = .white
        exitLabel.textAlignment = .center
        exitLabel.numberOfLines = 0
        exitLabel.text = .library(for: "video_player_playing_picture_in_picture")
        centerStackView.addArrangedSubview(exitLabel)
    }
    
    func setupCastOverlayView() {
        castOverlayView.isHidden = true
        castOverlayView.delegate = self
        addSubview(castOverlayView)
        NSLayoutConstraint.activate([
            castOverlayView.topAnchor.constraint(equalTo: topAnchor),
            castOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            castOverlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            castOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
        
        sessionManager.add(self)
        castOverlayView.setDevice(sessionManager.currentSession?.device)
    }
    
    func setupPlayerRetryView() {
        playerRetryView.delegate = self
        addSubview(playerRetryView)
        NSLayoutConstraint.activate([
            playerRetryView.centerXAnchor.constraint(equalTo: centerXAnchor),
            playerRetryView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func setupLoadingActivity() {
        loadingActivity.hidesWhenStopped = true
        loadingActivity.color = ImpulsePlayer.shared.appearance.accentColor
        loadingActivity.size = .small
        
        addSubview(loadingActivity)
        NSLayoutConstraint.activate([
            loadingActivity.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingActivity.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    // MARK: Observers
    func setupObservers() {
        setupFrameObserver()
        setupActivityObserver()
        setupSettingsObserver()
    }
    
    func setupFrameObserver() {
        publisher(for: \.bounds)
            .receive(on: RunLoop.main)
            .sink { [weak self] bounds in
                self?.playerLayer.frame = bounds
            }
            .store(in: &subscriptions)
    }
    
    func setupActivityObserver() {
        activityPassthroughSubject.eraseToAnyPublisher().debounce(for: .seconds(3), scheduler: DispatchQueue.main).sink { [weak self] _ in
            guard self?.timeControlStatus == .playing && self?.isSeeking == false else { return }
            self?.hideOverlay()
        }.store(in: &subscriptions)
    }
    
    func setupSettingsObserver() {
        ImpulsePlayer.shared.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                if settings.pictureInPictureEnabled {
                    self?.loadPictureInPictureControllerIfNeeded()
                } else {
                    self?.pictureInPictureControllerIfLoaded = nil
                }
            }
            .store(in: &subscriptions)
    }
    
    func setupPlayerObservers(for player: AVPlayer) {
        playerSubscribers = []
        
        player.publisher(for: \.timeControlStatus)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.timeControlStatus, on: self)
            .store(in: &playerSubscribers)
        
        player.publisher(for: \.rate)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                guard let self else { return }
                let isPlaying = rate > 0
                self.isPlaying = isPlaying
                self.standardPlayerOverlayView.switchToPlaying(isPlaying)
                
                if rate == 0 {
                    self.delegate?.onPause()
                } else {
                    self.delegate?.onPlay()
                }
            }
            .store(in: &playerSubscribers)
        
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1), queue: .main, using: { [weak self] _ in
            Task { @MainActor in
                self?.handleTimeChange()
            }
        })
        
        #if DEBUG
        setupDebugObservers(for: player)
        #endif
    }
    
    func setupDebugObservers(for player: AVPlayer) {
//        player?.currentItem?.publisher(for: \.tracks)
//            .receive(on: DispatchQueue.main)
//            .sink { tracks in
//                print(tracks)
//            }
//            .store(in: &subscriptions)
        
//        player?.currentItem?.publisher(for: \.presentationSize)
//            .receive(on: DispatchQueue.main)
//            .sink { tracks in
//                print(tracks)
//            }
//            .store(in: &subscriptions)
        
        player.publisher(for: \.error)
            .sink {[weak self] error in
                if let error {
                    NSLog("Error: \(error.localizedDescription)")
                    self?.delegate?.onError(message: error.localizedDescription)
                }
            }
            .store(in: &playerSubscribers)
        
        player.currentItem?.publisher(for: \.isPlaybackBufferEmpty)
            .removeDuplicates()
            .sink { bufferState in
                NSLog("Buffer Empty: \(bufferState)")
            }
            .store(in: &playerSubscribers)
        
        player.currentItem?.publisher(for: \.isPlaybackBufferFull)
            .removeDuplicates()
            .sink { bufferState in
                NSLog("Buffer Full: \(bufferState)")
            }
            .store(in: &playerSubscribers)
        
        player.currentItem?.publisher(for: \.isPlaybackLikelyToKeepUp)
            .removeDuplicates()
            .sink { bufferState in
                NSLog("Playback Likely To Keep Up: \(bufferState)")
            }
            .store(in: &playerSubscribers)
        
        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification) // Don't use generic av player item did end. look for specific player that did play to end
            .sink { [weak self] notification in
                guard let object = notification.object, let playerItem = object as? AVPlayerItem, self?.player?.currentItem == playerItem else {
                    return
                }
                self?.delegate?.onFinish()
            }
            .store(in: &playerSubscribers)
        
        NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification)
            .sink { [weak self] notification in
                guard let object = notification.object, let playerItem = object as? AVPlayerItem, self?.player?.currentItem == playerItem else {
                    return
                }
                self?.state = .error(error: playerItem.error)
            }
            .store(in: &playerSubscribers)
        
        NotificationCenter.default.publisher(for: .AVPlayerItemNewErrorLogEntry)
            .sink { notification in
                guard let object = notification.object, let playerItem = object as? AVPlayerItem else {
                    return
                }
                guard let errorLog: AVPlayerItemErrorLog = playerItem.errorLog() else {
                    return
                }
                NSLog("Error: \(errorLog)")
            }
            .store(in: &playerSubscribers)
    }
    
    func handleTimeChange() {
        print("Seeking: \(isSeeking)")
        guard !isSeeking, let time = player?.currentItem?.currentTime(), let duration = player?.currentItem?.duration else { return }
        // NOTE: Sets the current progress for the item in seconds
        progress = time.seconds
        standardPlayerOverlayView.setProgressTime(time, duration: duration)
    }
}

// MARK: - Load Video
private extension Player {
    
    func loadVideo(_ video: Player.Video) {
        standardPlayerOverlayView.setTitle(video.title, subtitle: video.subtitle)
        
        Task { [weak self] in
            self?.qualities = (try? await self?.manifestHelper.fetchSupportedVideoQualities(with: video.url)) ?? [.automatic]
        }
        
        loadAsset(withURL: video.url, headers: video.headers)
    }
    
    func loadAsset(withURL url: URL, headers: [String: String]?, onComplete: (() -> Void)? = nil) {
        if let headers {
            loadAsset(AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers]), onComplete: onComplete)
        } else {
            loadAsset(AVURLAsset(url: url), onComplete: onComplete)
        }
    }
    
    func loadAsset(_ asset: AVURLAsset, onComplete: (() -> Void)? = nil) {
        state = .loading
        // NOTE: Possible disable cellular access to an item
        //        let options = [AVURLAssetAllowsCellularAccessKey: false]
        
        playerItemSubscribers = []
        let playerItem: AVPlayerItem = AVPlayerItem(asset: asset)
        
        // Register to observe the status property before associating with player.
        playerItem.publisher(for: \.status)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    standardPlayerOverlayView.setDuration(playerItem.duration)
                    castOverlayView.setDuration(playerItem.duration)
                    
                    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try? AVAudioSession.sharedInstance().setActive(true)
                    
                    onComplete?()
                    state = .readyToPlay
                    activityPassthroughSubject.send()
                    self.delegate?.onVideoReady()
                case .failed:
                    self.state = .error(error: playerItem.error)
                    self.delegate?.onError(message: playerItem.error?.localizedDescription ?? "Unknown Error")
                default:
                    break
                }
            }
            .store(in: &playerItemSubscribers)
        
        playerItem.publisher(for: \.duration)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .map { $0.seconds }
            .assign(to: \.duration, on: self)
            .store(in: &playerItemSubscribers)
        
        playerItem.publisher(for: \.error)
            .receive(on: RunLoop.main)
            .assign(to: \.error, on: self)
            .store(in: &playerItemSubscribers)
        
        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: playerItem)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let item = notification.object as? AVPlayerItem, item == playerItem else { return }
                self?.itemDidEnd = true
            }
            .store(in: &playerItemSubscribers)
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.actionAtItemEnd = .pause
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
    }
    
    func loadCastMediaInformation(_ video: Video?, continueFrom: TimeInterval = 0, autoPlay: Bool) {
        guard let video else {
            print("No video available")
            return
        }
        
        guard let session = sessionManager.currentCastSession else {
            print("No cast session available")
            return
        }
        
        guard let remoteMediaClient = session.remoteMediaClient else {
            print("Remote media client is not available")
            return
        }
        remoteMediaClient.add(self)

        let mediaLoadRequestDataBuilder = GCKMediaLoadRequestDataBuilder()
        mediaLoadRequestDataBuilder.mediaInformation = createMediaInformation(video)
        mediaLoadRequestDataBuilder.startTime = continueFrom
        mediaLoadRequestDataBuilder.autoplay = NSNumber(value: autoPlay)
        let mediaLoadRequestData = mediaLoadRequestDataBuilder.build()
        
        let request = remoteMediaClient.loadMedia(with: mediaLoadRequestData)
        request.delegate = self
    }
    
    func createMediaInformation(_ video: Video) -> GCKMediaInformation {
        let mediaInfoBuilder = GCKMediaInformationBuilder.init(contentURL: video.url)
        
        let metadata = GCKMediaMetadata(metadataType: .movie)
        if let title = video.title {
            metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        }
        if let subtitle = video.subtitle {
            metadata.setString(subtitle, forKey: kGCKMetadataKeySubtitle)
        }
        mediaInfoBuilder.metadata = metadata
        
        return mediaInfoBuilder.build()
    }
}

// MARK: - Standard Overlay View Delegate
extension Player: StandardPlayerOverlayViewDelegate {
    
    func onClosePressed(in standardPlayerOverlayView: StandardPlayerOverlayView) {
        dismiss()
    }
    
    func onPictureInPicturePressed(in standardPlayerOverlayView: StandardPlayerOverlayView) {
        togglePictureInPicture()
    }
    
    func onGoForwardPressed(in standardPlayerOverlayView: StandardPlayerOverlayView) {
        activityPassthroughSubject.send()
        guard let player else { return }
        player.seek(to: player.currentTime() + CMTime(seconds: 10, preferredTimescale: 1))
    }
    
    func onPlayPausePressed(in standardPlayerOverlayView: StandardPlayerOverlayView) {
        activityPassthroughSubject.send()
        if player?.rate != 0 {
            player?.pause()
        } else {
            if itemDidEnd {
                seek(to: 0)
                itemDidEnd = false
            }
            player?.play()
        }
    }
    
    func onGoBackwardPressed(in standardPlayerOverlayView: StandardPlayerOverlayView) {
        activityPassthroughSubject.send()
        guard let player else { return }
        player.seek(to: player.currentTime() - CMTime(seconds: 10, preferredTimescale: 1))
    }
    
    func onSeekBarChanged(value: Float, in standardPlayerOverlayView: StandardPlayerOverlayView) {
        isSeeking = true
        
        guard let duration = player?.currentItem?.duration else {
            isSeeking = false
            return
        }
        let time = CMTime(seconds: Double(value) * duration.seconds, preferredTimescale: duration.timescale)
        standardPlayerOverlayView.setProgressTime(time, duration: duration)
    }
    
    func onSeeking(value: Float, in standardPlayerOverlayView: StandardPlayerOverlayView) {
        guard let duration = player?.currentItem?.duration else {
            isSeeking = false
            return
        }
        
        let time = CMTime(seconds: Double(value) * duration.seconds, preferredTimescale: duration.timescale)
        Task {
            await player?.seek(to: time)
            isSeeking = false
        }
    }
    
    func onToggleFullScreen(in standardPlayerOverlayView: StandardPlayerOverlayView) {
        isFullScreen.toggle()
    }
    
    @available(iOS 15.0, *)
    func onSelectQuality(in standardPlayerOverlayView: StandardPlayerOverlayView) {
        activityPassthroughSubject.send()
        delegate?.onQualityButtonPressed(qualities: qualities)
    }
    
    @available(iOS 15.0, *)
    func onSelectRate(in standardPlayerOverlayView: StandardPlayerOverlayView) {
        activityPassthroughSubject.send()
        delegate?.onRateButtonPressed()
    }

    func onSelectRemoteDevice(in standardPlayerOverlayView: StandardPlayerOverlayView) {
        activityPassthroughSubject.send()
        delegate?.onRemoteDeviceButtonPressed()
    }
    
    func onQualitySelected(quality: VideoQuality, in standardPlayerOverlayView: StandardPlayerOverlayView) {
        self.quality = quality
    }
    
    func onRateSelected(rate: Speed, in standardPlayerOverlayView: StandardPlayerOverlayView) {
        self.rate = rate
    }
}

// MARK: - Cast Overlay View Delegate
extension Player: CastOverlayViewDelegate {
    
    func onGoForwardPressed(in castOverlayView: CastOverlayView) {
        guard let currentSession = sessionManager.currentCastSession,
              playerVideoMatchesSession(currentSession),
              let remoteMediaClient = currentSession.remoteMediaClient,
              let remoteMediaStatus = remoteMediaClient.mediaStatus
        else {
            return
        }
        
        let progress = remoteMediaStatus.streamPosition + 10
        let duration = remoteMediaStatus.mediaInformation?.streamDuration ?? 0
        castOverlayView.setProgressTime(CMTime(seconds: progress, preferredTimescale: 1), duration: CMTime(seconds: duration, preferredTimescale: 1))
        
        let options = GCKMediaSeekOptions()
        options.interval = progress
        remoteMediaClient.seek(with: options)
    }
    
    func onPlayPausePressed(in castOverlayView: CastOverlayView) {
        guard let currentSession = sessionManager.currentCastSession,
              let remoteMediaClient = currentSession.remoteMediaClient,
              let remoteMediaStatus = remoteMediaClient.mediaStatus
        else {
            loadCastMediaInformation(video, continueFrom: player?.currentTime().seconds ?? 0, autoPlay: true)
            return
        }
        
        if !playerVideoMatchesSession(currentSession) {
            let currentTime = player?.currentTime().seconds
            loadCastMediaInformation(video, continueFrom: currentTime ?? 0, autoPlay: true)
        } else if remoteMediaStatus.playerState == .playing {
            remoteMediaClient.pause()
        } else if remoteMediaStatus.playerState == .paused {
            remoteMediaClient.play()
        }
    }
    
    func onGoBackwardPressed(in castOverlayView: CastOverlayView) {
        guard let currentSession = sessionManager.currentCastSession,
              playerVideoMatchesSession(currentSession),
              let remoteMediaClient = currentSession.remoteMediaClient,
              let remoteMediaStatus = remoteMediaClient.mediaStatus
        else {
            return
        }
        
        let progress = remoteMediaStatus.streamPosition - 10
        let duration = remoteMediaStatus.mediaInformation?.streamDuration ?? 0
        castOverlayView.setProgressTime(CMTime(seconds: progress, preferredTimescale: 1), duration: CMTime(seconds: duration, preferredTimescale: 1))
        
        let options = GCKMediaSeekOptions()
        options.interval = progress
        remoteMediaClient.seek(with: options)
    }
    
    func onSelectRemoteDevice(in castOverlayView: CastOverlayView) {
        delegate?.onRemoteDeviceButtonPressed()
    }
    
    func onSeekBarChanged(value: Float, in castOverlayView: CastOverlayView) {
        guard let duration = player?.currentItem?.duration else {
            return
        }
        let time = CMTime(seconds: Double(value) * duration.seconds, preferredTimescale: duration.timescale)
        castOverlayView.setProgressTime(time, duration: duration)
    }

    func onSeeking(value: Float, in castOverlayView: CastOverlayView) {
        guard let duration = player?.currentItem?.duration else {
            return
        }
        
        let time = CMTime(seconds: Double(value) * duration.seconds, preferredTimescale: duration.timescale)
        if let remoteMediaClient =  sessionManager.currentSession?.remoteMediaClient {
            let options = GCKMediaSeekOptions()
            options.interval = time.seconds
            remoteMediaClient.seek(with: options)
        }
    }
}

// MARK: - Player Retry View Delegate
extension Player: PlayerRetryViewDelegate {
    
    func onRetryPressed(in playerRetryView: PlayerRetryView) {
        guard let currentItem, let asset = currentItem.asset as? AVURLAsset else { return }
        let currentTime = currentItem.currentTime()
        loadAsset(asset) { [weak self] in
            self?.player?.seek(to: currentTime)
        }
    }
}

// MARK: - Picture in Picture Controller Delegate
extension Player: @preconcurrency AVPictureInPictureControllerDelegate {
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                                restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            delegate?.player(self, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: completionHandler)
        }
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            delegate?.playerWillStartPictureInPicture()
            controlType = .pictureInPicture
            
            if isEmbedded {
                isFullScreen = false
            } else {
                dismiss()
            }
        }
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            delegate?.playerDidStopPictureInPicture()
            if controlType == .pictureInPicture {
                controlType = .standard
            }
        }
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: any Error) {
        Task { @MainActor in
            delegate?.playerFailedToStartPictureInPictureWithError(error)
        }
    }
}

// MARK: - Video Dependency of the Player
extension Player {
    
    struct Video: Hashable {
        
        let title: String?
        let subtitle: String?
        let url: URL
        let headers: [String: String]?
        
        init(title: String?, subtitle: String?, url: URL, headers: [String: String]?) {
            self.title = title
            self.subtitle = subtitle
            self.url = url
            self.headers = headers
        }
    }
}

extension UIView {
    
    func forAutoLayout() -> Self {
        self.translatesAutoresizingMaskIntoConstraints = false
        return self
    }
    
    var isVisible: Bool {
        get {
            !isHidden
        }
        set {
            isHidden = !newValue
        }
    }
}

extension CALayer {
    var isVisible: Bool {
        get {
            !isHidden
        }
        set {
            isHidden = !newValue
        }
    }
}

extension String {

    func height(containerWidth: CGFloat) -> CGFloat {
        let rect = self.boundingRect(with: CGSize.init(width: containerWidth, height: CGFloat.greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                     context: nil)
        return ceil(rect.size.height)
    }

    func width(containerHeight: CGFloat) -> CGFloat {

        let rect = self.boundingRect(with: CGSize.init(width: CGFloat.greatestFiniteMagnitude, height: containerHeight),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                     context: nil)
        return ceil(rect.size.width)
    }
}

// MARK: Private Helper methods
private extension Player {

    func loadPictureInPictureControllerIfNeeded() {
        if pictureInPictureControllerIfLoaded == nil {
            pictureInPictureControllerIfLoaded = AVPictureInPictureController(playerLayer: playerLayer)
        }
    }
    
    ///Determines the visibility for overlays
    func determineOverlayVisibility() {
        // NOTE: Currently not setting picture in picture overlay visibility. Picture in picture is only possible if the video had already been loaded without error
        switch state {
        case .unknown, .loading:
            playerLayer.isVisible = false
            standardPlayerOverlayView.isVisible = false
            pictureInPictureOverlayView.isVisible = false
            castOverlayView.isVisible = false
            playerRetryView.isVisible = false
        case .readyToPlay:
            playerLayer.isVisible = controlType == .standard || (controlType == .casting && !castEnabled)
            standardPlayerOverlayView.isVisible = controlType == .standard || (controlType == .casting && !castEnabled)
            pictureInPictureOverlayView.isVisible = controlType == .pictureInPicture
            castOverlayView.isVisible = controlType == .casting && castEnabled
            playerRetryView.isVisible = false
        case .error:
            playerLayer.isVisible = false
            standardPlayerOverlayView.isVisible = false
            pictureInPictureOverlayView.isVisible = false
            castOverlayView.isVisible = false
            playerRetryView.isVisible = true
        }
    }
}

// MARK: - Google Cast
extension Player {
    
    // MARK: Stop Casting
    func stopCastingIfNeeded() {
        guard let currentSession = sessionManager.currentCastSession,
              playerVideoMatchesSession(currentSession)
        else {
            return
        }
        
        stoppedCastingFromThisVideo = true
        sessionManager.endSessionAndStopCasting(true)
    }
    
    // MARK: Mode switching
    func switchToLocalPlayback(shouldAutoPlay: Bool, continueFromTime: TimeInterval = 0) {
        controlType = .standard
        
        if stoppedCastingFromThisVideo {
            stoppedCastingFromThisVideo = false
            seek(to: continueFromTime)
            
            if shouldAutoPlay {
                play()
            }
        }
        
        sessionManager.currentCastSession?.remoteMediaClient?.remove(self)
    }

    func switchToRemotePlayback(shouldAutoPlay: Bool) {
        controlType = .casting
        
        pause()
        pictureInPictureControllerIfLoaded?.stopPictureInPicture()
        
        sessionManager.currentCastSession?.remoteMediaClient?.add(self)
        if startedCastingFromThisVideo {
            startedCastingFromThisVideo = false
            loadCastMediaInformation(video, continueFrom: player?.currentTime().seconds ?? 0, autoPlay: shouldAutoPlay)
        }
    }
    
    func playerVideoMatchesSession(_ session: GCKSession) -> Bool {
        session.remoteMediaClient?.mediaStatus?.mediaInformation?.contentURL == video?.url
    }
}

// MARK: GCKSessionManagerListener
extension Player: @preconcurrency GCKSessionManagerListener {
      
    func sessionManager(_ manager: GCKSessionManager, didStart session: GCKSession) {
        Task { @MainActor in
            switchToRemotePlayback(shouldAutoPlay: playerVideoMatchesSession(session) || isPlaying)
            
            castOverlayView.setDevice(session.device)
        }
    }
    
    func sessionManager(_: GCKSessionManager, didResumeSession session: GCKSession) {
        Task { @MainActor in
            switchToRemotePlayback(shouldAutoPlay: false)
            
            castOverlayView.setDevice(session.device)
        }
    }
    
    func sessionManager(_ manager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        Task { @MainActor in
            switchToLocalPlayback(shouldAutoPlay: playerVideoMatchesSession(session), continueFromTime: castMediaController.lastKnownStreamPosition)
            
            castOverlayView.setDevice(nil)
        }
    }
    
    func sessionManager(_: GCKSessionManager,
                        didFailToResumeSession session: GCKSession,
                        withError _: Error?
    ) {
        Task { @MainActor in
            switchToLocalPlayback(shouldAutoPlay: playerVideoMatchesSession(session), continueFromTime: castMediaController.lastKnownStreamPosition)
            
            castOverlayView.setDevice(nil)
        }
    }
}

// MARK: GCKRequestDelegate
extension Player: @preconcurrency GCKRequestDelegate {
    
    func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        Task { @MainActor in
            print("Media status: Did fail for: \(video?.url.lastPathComponent)")
            // TODO: Determine what to do when the request to load the media information on the receiver id failed
        }
    }
}

// MARK: GCKRemoteMediaClientListener
extension Player: @preconcurrency GCKRemoteMediaClientListener {
    
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
        Task { @MainActor in
            guard let mediaStatus, mediaStatus.mediaInformation?.contentURL == video?.url else {
                print("Media status: Switching player state to nil for: \(video?.url.lastPathComponent)")
                castOverlayView.switchPlayerState(nil)
                return
            }
            print("Media status: Switching player state on cast overlay for found URL: \(mediaStatus.mediaInformation?.contentURL?.lastPathComponent)")
            castOverlayView.switchPlayerState(mediaStatus.playerState)
            
            let progress = mediaStatus.streamPosition
            let duration = mediaStatus.mediaInformation?.streamDuration ?? 0
            castOverlayView.setProgressTime(CMTime(seconds: progress, preferredTimescale: 1), duration: CMTime(seconds: duration, preferredTimescale: 1))
        }
    }
}
