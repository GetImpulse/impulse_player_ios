import AVKit
//import MediaPlayer
import Combine

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
    
    private let overlayView: UIView = UIView().forAutoLayout()
    
    private let topLeadingToolBar: UIStackView = UIStackView().forAutoLayout()
    private let fullScreenInfoContainer: UIStackView = UIStackView().forAutoLayout()
    private let closeButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    private let titleLabel: UILabel = UILabel().forAutoLayout()
    private let subtitleLabel: UILabel = UILabel().forAutoLayout()
    
    private let topTrailingToolBar: UIStackView = UIStackView().forAutoLayout()
    private let routePickerView: AVRoutePickerView = AVRoutePickerView().forAutoLayout()
    private let pipButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    
    private let centerPlaybackControlBar: UIStackView = UIStackView().forAutoLayout()
    private let goBackwardButton: PlayerPlaybackButton = PlayerPlaybackButton().forAutoLayout()
    private let playPauseButton: PlayerPlaybackButton = PlayerPlaybackButton().forAutoLayout()
    private let goForwardButton: PlayerPlaybackButton = PlayerPlaybackButton().forAutoLayout()
    private let loadingActivity: PlayerLoadingView = PlayerLoadingView().forAutoLayout()
    
    private let timeLine: PlayerTimeline = PlayerTimeline().forAutoLayout()
    private let currentTimeLabel: UILabel = UILabel().forAutoLayout()
    private let timeSeparatorLabel: UILabel = UILabel().forAutoLayout()
    private let durationLabel: UILabel = UILabel().forAutoLayout()
    
    private let bottomLeadingToolBar: UIStackView = UIStackView().forAutoLayout()
    private let rateButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    private let qualityButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    
    private let bottomTrailingToolBar: UIStackView = UIStackView().forAutoLayout()
    private let fullScreenButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    
    private let pictureInPictureOverlayView: UIView = UIView().forAutoLayout()
    
    private let retryContainer: UIStackView = UIStackView().forAutoLayout()
    private let retryLabel: UILabel = UILabel().forAutoLayout()
    private let retryErrorCodeLabel: UILabel = UILabel().forAutoLayout()
    private let retryButton: UIButton = UIButton(type: .roundedRect).forAutoLayout()
    
    private lazy var playbackControls: [UIView] = [goBackwardButton, playPauseButton, goForwardButton]
    private lazy var videoControls: [UIView] = [routePickerView, pipButton, loadingActivity, currentTimeLabel, timeSeparatorLabel, durationLabel, rateButton, qualityButton, fullScreenButton]
    
    // MARK: Constraints
    private var verticalLayoutPaddingConstraints: [NSLayoutConstraint] = []
    private var horizontalLayoutPaddingConstraints: [NSLayoutConstraint] = []
    private var timeWidthConstraint: NSLayoutConstraint!
    
    // MARK: DI
    var isEmbedded: Bool {
        didSet {
            fullScreenInfoContainer.isHidden = !isFullScreen && isEmbedded
            fullScreenButton.isHidden = !isEmbedded
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
    private let timeLabelSpacing: CGFloat = 4.0
    
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
                pipButton.isEnabled = pictureInPictureControllerIfLoaded?.isPictureInPicturePossible ?? true
                pictureInPictureControllerIfLoaded?.publisher(for: \.isPictureInPicturePossible)
                    .removeDuplicates()
                    .receive(on: RunLoop.main)
                    .sink { [weak self] change in
                        self?.pipButton.isEnabled = change
                    }.store(in: &subscriptions)
                
                pipButton.isHidden = !ImpulsePlayer.shared.settings.pictureInPictureEnabled
            }
        }
    }
    
    private var qualities: [VideoQuality] = [.automatic] {
        didSet {
            if #unavailable(iOS 15.0) {
                let actions = qualities.map { quality in
                    UIAction(title: quality.resolution) { [weak self] action in
                        self?.quality = quality
                    }
                }
                let menu = UIMenu(title: VideoQuality.header, children: actions)
                self.qualityButton.menu = menu
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
    
    private var isSeeking: Bool = false
    
    // MARK: Internal Properties
    weak var delegate: InternalPlayerDelegate?
    
    var isFullScreen: Bool = false {
        didSet {
            fullScreenButton.setImage(.library(named: isFullScreen ? "Video/FullScreen/Exit" : "Video/FullScreen/Start"), for: .normal)
            
            loadingActivity.size = isFullScreen ? .large : .small
            playPauseButton.heightConstraintConstant = isFullScreen ? 68.0: 48.0
            horizontalLayoutPaddingConstraints.forEach { $0.constant = isFullScreen ? 16.0: 16.0 } // NOTE: It's possible to make the fullscreen horizontal padding differ from non-fullscreen
            verticalLayoutPaddingConstraints.forEach { $0.constant = isFullScreen ? 8.0: 8.0 } // NOTE: It's possible to make the fullscreen horizontal padding differ from non-fullscreen
            
            fullScreenInfoContainer.isHidden = !isFullScreen && isEmbedded
            
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
            rateButton.setImage(.library(named: rate.iconName), for: .normal)
        }
    }
    
    var quality: VideoQuality = .automatic {
        didSet {
            player?.currentItem?.preferredPeakBitRate = quality.bitrate
            qualityButton.setTitle(quality.definition.buttonText, for: .normal)
            qualityButton.setImage(nil, for: .normal)
            var image: UIImage?
            if let iconName = quality.definition.iconName {
                image = .library(named: iconName)
            }
            qualityButton.setImage(image, for: .normal)
        }
    }
    
    var state: State = .unknown {
        didSet {
            switch state {
            case .unknown:
                videoState = .loading
            case .loading:
                videoState = .loading
                videoControls.forEach { $0.isHidden = true }
                playbackControls.forEach { $0.isHidden = true }
                timeLine.alpha = 0
                loadingActivity.startAnimating()
                retryContainer.isHidden = true
            case .readyToPlay:
                videoState = .ready
                videoControls.forEach {
                    // NOTE: Making an exception to display pip button when setting is disabled.
                    if $0 == pipButton {
                        $0.isHidden = !ImpulsePlayer.shared.settings.pictureInPictureEnabled
                    } else {
                        $0.isHidden = false
                    }
                }
                playbackControls.forEach { $0.isHidden = false }
                timeLine.alpha = 1
                loadingActivity.stopAnimating()
                retryContainer.isHidden = true
            case .error(let error):
                videoState = .error
                videoControls.forEach { $0.isHidden = true }
                playbackControls.forEach { $0.isHidden = true }
                timeLine.alpha = 0
                loadingActivity.stopAnimating()
                
                retryLabel.text = .library(for: "controls_error_title")
                if let nsError = error as? NSError {
                    retryErrorCodeLabel.text = String(format: .library(for: "controls_error_x"), nsError.code)
                    retryErrorCodeLabel.isHidden = false
                } else {
                    retryErrorCodeLabel.isHidden = true
                }
                
                retryContainer.isHidden = false
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
    
    // Observable properties
    @objc dynamic var isPlaying: Bool = false
    @objc dynamic var videoState: PlayerState = .loading
    @objc dynamic var progress: TimeInterval = 0
    @objc dynamic var duration: TimeInterval = 0
    @objc dynamic var error: Error?
    
    // MARK: Internal Read-Only
    var currentItem: AVPlayerItem? {
        player?.currentItem
    }
    
    // MARK: Internal Functions
    func load(video: Video) {
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
            topTrailingToolBar.addArrangedSubview(button)
        case .bottomStart:
            bottomLeadingToolBar.addArrangedSubview(button)
        case .bottomEnd:
            bottomTrailingToolBar.addArrangedSubview(button)
        }
        
        developerButtons[key] = button
    }
    
    func removeButton(key: String) {
        if let button = developerButtons[key] {
            button.removeFromSuperview()
        }
    }
}

// MARK: - Actions
private extension Player {
    
    @objc func toggleFullScreen() {
        isFullScreen.toggle()
    }
    
    @objc func dismiss() {
        activityPassthroughSubject.send()
        if isEmbedded {
            isFullScreen = false
        } else {
            delegate?.onDismissPressed()
        }
    }
    
    @objc func playPause() {
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
    
    @objc func goForward() {
        activityPassthroughSubject.send()
        guard let player else { return }
        player.seek(to: player.currentTime() + CMTime(seconds: 10, preferredTimescale: 1))
    }
    
    @objc func goBackward() {
        activityPassthroughSubject.send()
        guard let player else { return }
        player.seek(to: player.currentTime() - CMTime(seconds: 10, preferredTimescale: 1))
    }
    
    @objc func seekBarChanged() {
        isSeeking = true
        guard let duration = player?.currentItem?.duration else { return }
        let time = CMTime(seconds: Double(timeLine.value) * duration.seconds, preferredTimescale: duration.timescale)
        currentTimeLabel.text = cmTimeToMinutesAndSeconds(cmTime: time)
    }
    
    @objc func seeking() {
        guard let duration = player?.currentItem?.duration else {
            isSeeking = false
            return
        }
        let time = CMTime(seconds: Double(timeLine.value) * duration.seconds, preferredTimescale: duration.timescale)
        Task {
            await player?.seek(to: time)
            isSeeking = false
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
    
    @objc func retry() {
        guard let currentItem, let asset = currentItem.asset as? AVURLAsset else { return }
        let currentTime = currentItem.currentTime()
        loadAsset(withURL: asset.url) { [weak self] in
            self?.player?.seek(to: currentTime)
        }
    }
    
    @available(iOS 15.0, *)
    @objc func selectRate() {
        activityPassthroughSubject.send()
        delegate?.onRateButtonPressed()
    }
    
    @available(iOS 15.0, *)
    @objc func selectQuality() {
        activityPassthroughSubject.send()
        delegate?.onQualityButtonPressed(qualities: qualities)
    }
    
    @objc func showOverlay() {
        activityPassthroughSubject.send()
        UIView.animate(withDuration: 0.5) { [weak self] in
            self?.overlayView.alpha = 1
        }
    }
    
    @objc func hideOverlay() {
        guard case .readyToPlay = state else { return }
        UIView.animate(withDuration: 0.5) { [weak self] in
            self?.overlayView.alpha = 0
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
        
        setupLayout()
        setupObservers()
    }
    
    func setupLayout() {
        setupOverlayView()
        setupPictureInPictureOverlayView()
    }
    
    func setupOverlayView() {
        overlayView.backgroundColor = .black.withAlphaComponent(0.3)
        
        let hideTapGesture = UITapGestureRecognizer(target: self, action: #selector(hideOverlay))
        hideTapGesture.numberOfTapsRequired = 1
        overlayView.addGestureRecognizer(hideTapGesture)
        
        addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
        
        let layout = UIStackView().forAutoLayout()
        layout.axis = .vertical
        layout.spacing = 8.0
        layout.distribution = .equalSpacing
        layout.alignment = .center
        overlayView.addSubview(layout)
        
        verticalLayoutPaddingConstraints = [
            layout.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 8.0),
            overlayView.bottomAnchor.constraint(equalTo: layout.bottomAnchor, constant: 8.0)
        ]
        horizontalLayoutPaddingConstraints = [
            overlayView.trailingAnchor.constraint(equalTo: layout.trailingAnchor, constant: 16.0),
            layout.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 16.0)
        ]
        [verticalLayoutPaddingConstraints, horizontalLayoutPaddingConstraints].flatMap { $0 }.forEach { $0.isActive = true }
        
        let topLayout = setupTopLayout()
        layout.addArrangedSubview(topLayout)
        topLayout.widthAnchor.constraint(equalTo: layout.widthAnchor).isActive = true
        topLayout.setContentHuggingPriority(.required, for: .vertical)
        
        let centerLayout = setupCenterLayout()
        overlayView.addSubview(centerLayout)
        NSLayoutConstraint.activate([
            centerLayout.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            centerLayout.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor)
        ])
        
        let bottomLayout = setupBottomLayout()
        layout.addArrangedSubview(bottomLayout)
        bottomLayout.widthAnchor.constraint(equalTo: layout.widthAnchor).isActive = true
        bottomLayout.setContentHuggingPriority(.required, for: .vertical)
    }
    
    // MARK: Top Layout
    func setupTopLayout() -> UIStackView {
        let topLayout = UIStackView().forAutoLayout()
        topLayout.axis = .horizontal
        topLayout.spacing = 0
        topLayout.alignment = .center
        topLayout.distribution = .equalSpacing
        //        topLayout.backgroundColor = .yellow
        
        topLeadingToolBar.axis = .horizontal
        topLeadingToolBar.spacing = 8.0
        topLeadingToolBar.alignment = .center
        topLeadingToolBar.distribution = .fill
        //        topLeadingToolBar.backgroundColor = .blue
        topLayout.addArrangedSubview(topLeadingToolBar)
        
        topTrailingToolBar.axis = .horizontal
        topTrailingToolBar.spacing = 8.0
        topTrailingToolBar.alignment = .center
        topTrailingToolBar.distribution = .fill
        //        topTrailingToolBar.backgroundColor = .purple
        topLayout.addArrangedSubview(topTrailingToolBar)
        
        setupTopLayoutBars()
        
        return topLayout
    }
    
    func setupTopLayoutBars() {
        setupTopLeadingLayoutBar()
        setupTopTrailingLayoutBar()
    }
    
    func setupTopLeadingLayoutBar() {
        setupFullScreenInfoContainer()
    }
    
    func setupFullScreenInfoContainer() {
        fullScreenInfoContainer.isHidden = !isFullScreen && isEmbedded
        fullScreenInfoContainer.axis = .horizontal
        fullScreenInfoContainer.spacing = 8.0
        fullScreenInfoContainer.alignment = .center
        topLeadingToolBar.addArrangedSubview(fullScreenInfoContainer)
        
        setupCloseButton()
        fullScreenInfoContainer.addArrangedSubview(closeButton)
        
        let infoContainer = setupInfoContainer()
        fullScreenInfoContainer.addArrangedSubview(infoContainer)
    }
    
    func setupCloseButton()  {
        closeButton.setImage(.library(named: "Back_Icon"), for: .normal)
        closeButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
    }
    
    func setupInfoContainer() -> UIStackView {
        let infoContainer = UIStackView().forAutoLayout()
        infoContainer.axis = .vertical
        infoContainer.spacing = 0
        infoContainer.alignment = .leading
        topLeadingToolBar.addArrangedSubview(infoContainer)
        
        setupTitleLabel()
        infoContainer.addArrangedSubview(titleLabel)
        
        setupSubtitleLabel()
        infoContainer.addArrangedSubview(subtitleLabel)
        
        return infoContainer
    }
    
    func setupTitleLabel() {
        titleLabel.font = ImpulsePlayer.shared.appearance.h4.font
        titleLabel.textColor = .white
    }
    
    func setupSubtitleLabel() {
        subtitleLabel.font = ImpulsePlayer.shared.appearance.s1.font
        subtitleLabel.textColor = .white
    }
    
    func setupTopTrailingLayoutBar() {
        // NOTE: Currently not displaying airplay. Not correctly displayed and unsure if standard button is good enough.
//        setupAirplayButton()
        setupPictureInPictureButton()
    }
    
    func setupAirplayButton() {
        routePickerView.tintColor = .white
        routePickerView.prioritizesVideoDevices = true
        routePickerView.heightAnchor.constraint(equalToConstant: 20.0).isActive = true
        routePickerView.widthAnchor.constraint(equalTo: routePickerView.heightAnchor).isActive = true
        topTrailingToolBar.addArrangedSubview(routePickerView)
    }
    
    func setupPictureInPictureButton() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }
        
        let startImage: UIImage? = .library(named: "Video/PictureInPicture/Start")
        let stopImage: UIImage? = .library(named: "Video/PictureInPicture/Exit")
        
        pipButton.setImage(startImage, for: .normal)
        pipButton.setImage(stopImage, for: .selected)
        
        pipButton.addTarget(self, action: #selector(togglePictureInPicture), for: .touchUpInside)
        pipButton.isHidden = true
        topTrailingToolBar.addArrangedSubview(pipButton)
        
        if ImpulsePlayer.shared.settings.pictureInPictureEnabled {
            loadPictureInPictureControllerIfNeeded()
        }
    }
    
    // MARK: Center Layout
    func setupCenterLayout() -> UIView {
        let centerLayout = UIView().forAutoLayout()
        
        centerPlaybackControlBar.axis = .horizontal
        centerPlaybackControlBar.spacing = 32.0
        centerPlaybackControlBar.alignment = .center
        centerPlaybackControlBar.distribution = .fill
        centerLayout.addSubview(centerPlaybackControlBar)
        NSLayoutConstraint.activate([
            centerPlaybackControlBar.topAnchor.constraint(equalTo: centerLayout.topAnchor),
            centerPlaybackControlBar.leadingAnchor.constraint(equalTo: centerLayout.leadingAnchor),
            centerPlaybackControlBar.bottomAnchor.constraint(equalTo: centerLayout.bottomAnchor),
            centerPlaybackControlBar.trailingAnchor.constraint(equalTo: centerLayout.trailingAnchor),
        ])
        
        setupCenterLayoutBar()
        
        return centerLayout
    }
    
    func setupCenterLayoutBar() {
        setupGoBackwardButton()
        setupPlayPauseButton()
        setupGoForwardButton()
        setupLoadingActivity()
        setupRetryContainer()
    }
    
    func setupGoBackwardButton() {
        goBackwardButton.setImage(.library(named: "Video/Playback/Replay"), for: .normal)
        goBackwardButton.addTarget(self, action: #selector(goBackward), for: .touchUpInside)
        goBackwardButton.heightConstraintConstant = 36.0
        
        centerPlaybackControlBar.addArrangedSubview(goBackwardButton)
    }
    
    func setupPlayPauseButton() {
        playPauseButton.setImage(.library(named: "Video/Playback/Play"), for: .normal)
        playPauseButton.addTarget(self, action: #selector(playPause), for: .touchUpInside)
        playPauseButton.heightConstraintConstant = isFullScreen ? 68.0: 48.0
        
        centerPlaybackControlBar.addArrangedSubview(playPauseButton)
    }
    
    func setupGoForwardButton() {
        goForwardButton.setImage(.library(named: "Video/Playback/Forward"), for: .normal)
        goForwardButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        goForwardButton.heightConstraintConstant = 36.0
        
        centerPlaybackControlBar.addArrangedSubview(goForwardButton)
    }
    
    func setupLoadingActivity() {
        loadingActivity.hidesWhenStopped = true
        loadingActivity.color = ImpulsePlayer.shared.appearance.accentColor
        loadingActivity.size = .small
        
        centerPlaybackControlBar.addArrangedSubview(loadingActivity)
    }
    
    func setupRetryContainer() {
        retryContainer.isHidden = true
        retryContainer.axis = .vertical
        retryContainer.spacing = 16.0
        retryContainer.alignment = .center
        retryContainer.distribution = .fill
        centerPlaybackControlBar.addArrangedSubview(retryContainer)
        
        let headerStackView = UIStackView(arrangedSubviews: [retryLabel, retryErrorCodeLabel]).forAutoLayout()
        headerStackView.axis = .vertical
        headerStackView.spacing = 4.0
        headerStackView.alignment = .center
        headerStackView.distribution = .fill
        retryContainer.addArrangedSubview(headerStackView)
        
        setupRetryLabel()
        setupRetryErrorCodeLabel()
        setupRetryButton()
    }
    
    func setupRetryLabel() {
        retryLabel.numberOfLines = 0
        retryLabel.font = ImpulsePlayer.shared.appearance.h3.font
        retryLabel.textColor = .white
        retryLabel.textAlignment = .center
    }
    
    func setupRetryErrorCodeLabel() {
        retryErrorCodeLabel.numberOfLines = 0
        retryErrorCodeLabel.font = ImpulsePlayer.shared.appearance.l4.font
        retryErrorCodeLabel.textColor = .white.withAlphaComponent(0.6)
        retryErrorCodeLabel.textAlignment = .center
    }
    
    func setupRetryButton() {
        if #available(iOS 15.0, *) {
            retryButton.configuration = nil
        }
        
        retryButton.backgroundColor = .clear
        retryButton.tintColor = .white
        retryButton.layer.cornerRadius = 16.0
        retryButton.layer.borderColor = UIColor.white.cgColor
        retryButton.layer.borderWidth = 1.0
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20.0, bottom: 0, right: 20.0)
        retryButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4.0, bottom: 0, right: 4.0)
        retryButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4.0, bottom: 0, right: -4.0)
        retryButton.titleLabel?.font = ImpulsePlayer.shared.appearance.h4.font
        retryButton.setImage(.library(named: "Video/RetryIcon"), for: .normal)
        retryButton.setTitleColor(UIColor.white, for: .normal)
        retryButton.setTitle(.library(for: "controls_retry"), for: .normal)
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        retryContainer.addArrangedSubview(retryButton)
        retryButton.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
    }
    
    // MARK: Bottom Layout
    func setupBottomLayout() -> UIStackView {
        let containingLayout = UIStackView().forAutoLayout()
        containingLayout.axis = .vertical
        containingLayout.spacing = 8.0
        containingLayout.alignment = .center
        containingLayout.distribution = .fill
        
        let timelineLayout = UIStackView().forAutoLayout()
        timelineLayout.axis = .horizontal
        timelineLayout.spacing = 8.0
        timelineLayout.alignment = .center
        timelineLayout.distribution = .fill
        containingLayout.addArrangedSubview(timelineLayout)
        timelineLayout.widthAnchor.constraint(equalTo: containingLayout.widthAnchor).isActive = true
        
        timelineLayout.addArrangedSubview(timeLine)
        
        let timeTextLayout = UIStackView().forAutoLayout()
        timeTextLayout.axis = .horizontal
        timeTextLayout.spacing = timeLabelSpacing
        timeTextLayout.alignment = .center
        timeTextLayout.distribution = .fill
        timelineLayout.addArrangedSubview(timeTextLayout)
        timeWidthConstraint = timeTextLayout.widthAnchor.constraint(equalToConstant: 0)
        timeTextLayout.setContentHuggingPriority(.required, for: .horizontal)
        
        timeTextLayout.addArrangedSubview(currentTimeLabel)
        timeTextLayout.addArrangedSubview(timeSeparatorLabel)
        timeTextLayout.addArrangedSubview(durationLabel)
        
        let bottomLayout = UIStackView().forAutoLayout()
        bottomLayout.axis = .horizontal
        bottomLayout.spacing = 0
        bottomLayout.alignment = .center
        bottomLayout.distribution = .equalSpacing
        containingLayout.addArrangedSubview(bottomLayout)
        bottomLayout.widthAnchor.constraint(equalTo: containingLayout.widthAnchor).isActive = true

        bottomLeadingToolBar.axis = .horizontal
        bottomLeadingToolBar.spacing = 8.0
        bottomLeadingToolBar.alignment = .center
        bottomLeadingToolBar.distribution = .fill
        bottomLayout.addArrangedSubview(bottomLeadingToolBar)
        
        bottomTrailingToolBar.axis = .horizontal
        bottomTrailingToolBar.spacing = 8.0
        bottomTrailingToolBar.alignment = .center
        bottomTrailingToolBar.distribution = .fill
        bottomLayout.addArrangedSubview(bottomTrailingToolBar)
        
        setupBottomLayoutBars()
        
        return containingLayout
    }
        
    func setupBottomLayoutBars() {
        setupTimeLineBar()
        
        setupBottomLeadingLayoutBar()
        setupBottomTrailingLayoutBar()
    }
    
    func setupBottomLeadingLayoutBar() {
        setupQualityButton()
        setupRateButton()
    }
    
    func setupQualityButton() {
        // NOTE: Quality button becomes available when a video is loaded in
        quality = .automatic
        if #available(iOS 15.0, *) {
            qualityButton.addTarget(self, action: #selector(selectQuality), for: .touchUpInside)
        } else {
            qualityButton.showsMenuAsPrimaryAction = true
        }
        bottomLeadingToolBar.addArrangedSubview(qualityButton)
    }
    
    func setupRateButton() {
        rateButton.setImage(.library(named: Speed._1.iconName), for: .normal)
        bottomLeadingToolBar.addArrangedSubview(rateButton)
        
        if #available(iOS 15.0, *) {
            self.rateButton.addTarget(self, action: #selector(selectRate), for: .touchUpInside)
            return
        }
        
        let actions = Speed.allCases.map { rate in
            UIAction(title: "\(rate.speed)x") { [weak self] _ in
                self?.rate = rate
            }
        }
        let menu = UIMenu(title: Speed.header, children: actions)
        self.rateButton.menu = menu
        self.rateButton.showsMenuAsPrimaryAction = true
    }
    
    func setupBottomTrailingLayoutBar() {
        setupFullScreenButton()
    }
    
    func setupFullScreenButton() {
        fullScreenButton.isHidden = !isEmbedded
        fullScreenButton.setImage(.library(named: isFullScreen ? "Video/FullScreen/Exit" : "Video/FullScreen/Start"), for: .normal)
        fullScreenButton.addTarget(self, action: #selector(toggleFullScreen), for: .touchUpInside)
        bottomTrailingToolBar.addArrangedSubview(fullScreenButton)
    }
    
    func setupTimeLineBar() {
        setupTimeLine()
        setupTimeLabels()
    }
    
    func setupTimeLine() {
        timeLine.addTarget(self, action: #selector(seekBarChanged), for: .valueChanged)
        timeLine.addTarget(self, action: #selector(seeking), for: [.touchUpInside, .touchUpOutside])
        timeLine.setColoredThumb()
    }
    
    func setupTimeLabels() {
        setupCurrentTimeLabel()
        setupTimeSeparatorLabel()
        setupDurationLabel()
    }
    
    func setupCurrentTimeLabel() {
        currentTimeLabel.text = cmTimeToMinutesAndSeconds(cmTime: .zero)
        currentTimeLabel.font = ImpulsePlayer.shared.appearance.l7.font
        currentTimeLabel.textColor = .white
        currentTimeLabel.textAlignment = .right
    }
    
    func setupTimeSeparatorLabel() {
        timeSeparatorLabel.text = "/"
        timeSeparatorLabel.font = ImpulsePlayer.shared.appearance.l7.font
        timeSeparatorLabel.textColor = .white
    }
    
    func setupDurationLabel() {
        durationLabel.text = cmTimeToMinutesAndSeconds(cmTime: .zero)
        durationLabel.font = ImpulsePlayer.shared.appearance.l7.font
        durationLabel.textColor = .white.withAlphaComponent(0.6)
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
                
                self?.pipButton.isHidden = !settings.pictureInPictureEnabled
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
                self.isPlaying = rate > 0
                self.playPauseButton.setImage(.library(named: rate != 0 ? "Video/Playback/Pause" : "Video/Playback/Play"), for: .normal)
                if rate == 0 {
                    self.delegate?.onPause()
                } else {
                    self.delegate?.onPlay()
                }
            }
            .store(in: &playerSubscribers)
        
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
        guard !isSeeking, let time = player?.currentItem?.currentTime(), let duration = player?.currentItem?.duration else { return }
        // NOTE: Sets the current progress for the item in seconds
        progress = time.seconds
        
        currentTimeLabel.text = cmTimeToMinutesAndSeconds(cmTime: time)
        let value = time.seconds / duration.seconds
        timeLine.value = Float(value)
    }
                                                       
    func cmTimeToMinutesAndSeconds(cmTime: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(cmTime)
        if totalSeconds > 0 {
            let minutes = Int(totalSeconds) / 60
            let seconds = Int(totalSeconds) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return "00:00"
        }
    }
}

// MARK: - Load Video
private extension Player {
    
    func loadVideo(_ video: Player.Video) {
        titleLabel.text = video.title
        subtitleLabel.text = video.subtitle
        
        Task { [weak self] in
            self?.qualities = (try? await self?.manifestHelper.fetchSupportedVideoQualities(with: video.url)) ?? [.automatic]
        }
        
        loadAsset(withURL: video.url)
    }
    
    func loadAsset(withURL url: URL, onComplete: (() -> Void)? = nil) {
        state = .loading
        // NOTE: Possible disable cellular access to an item
//        let options = [AVURLAssetAllowsCellularAccessKey: false]
        let asset = AVURLAsset(url: url)
        
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
                    let durationMaxWidth = cmTimeToMinutesAndSeconds(cmTime: playerItem.duration).width(containerHeight: 1.0)
                    // NOTE: The maximum width of the time label is the items duration * 2 + spacing between items and a fault margin of 4.0
                    let maxWidth = durationMaxWidth * 2 + timeLabelSpacing * 2 + 4.0
                    timeWidthConstraint.constant = maxWidth
                    timeWidthConstraint.isActive = maxWidth > 0
                    durationLabel.text = cmTimeToMinutesAndSeconds(cmTime: playerItem.duration)
                    
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
}

// MARK: - Picture in Picture Controller Delegate
extension Player: @preconcurrency AVPictureInPictureControllerDelegate {
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                                restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        delegate?.player(self, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: completionHandler)
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.playerWillStartPictureInPicture()
        overlayView.isHidden = true
        playerLayer.isHidden = true
        pictureInPictureOverlayView.isHidden = false
        if isEmbedded {
            isFullScreen = false
        } else {
            dismiss()
        }
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.playerDidStopPictureInPicture()
        overlayView.isHidden = false
        playerLayer.isHidden = false
        pictureInPictureOverlayView.isHidden = true
        bringSubviewToFront(overlayView)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: any Error) {
        delegate?.playerFailedToStartPictureInPictureWithError(error)
    }
}

// MARK: - Video Dependency of the Player
extension Player {
    
    struct Video: Hashable {
        
        let title: String?
        let subtitle: String?
        let url: URL
        
        init(title: String?, subtitle: String?, url: URL) {
            self.title = title
            self.subtitle = subtitle
            self.url = url
        }
    }
}

extension UIView {
    
    func forAutoLayout() -> Self {
        self.translatesAutoresizingMaskIntoConstraints = false
        return self
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

    private func loadPictureInPictureControllerIfNeeded() {
        if pictureInPictureControllerIfLoaded == nil {
            pictureInPictureControllerIfLoaded = AVPictureInPictureController(playerLayer: playerLayer)
        }
    }
}
