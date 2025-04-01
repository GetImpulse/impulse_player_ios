import UIKit
import AVKit
import GoogleCast
import Combine

@MainActor
protocol StandardPlayerOverlayViewDelegate: AnyObject {
    
    func onClosePressed(in standardPlayerOverlayView: StandardPlayerOverlayView)
    func onPictureInPicturePressed(in standardPlayerOverlayView: StandardPlayerOverlayView)
    func onGoForwardPressed(in standardPlayerOverlayView: StandardPlayerOverlayView)
    func onPlayPausePressed(in standardPlayerOverlayView: StandardPlayerOverlayView)
    func onGoBackwardPressed(in standardPlayerOverlayView: StandardPlayerOverlayView)
    func onSeekBarChanged(value: Float, in standardPlayerOverlayView: StandardPlayerOverlayView)
    func onSeeking(value: Float, in standardPlayerOverlayView: StandardPlayerOverlayView)
    func onToggleFullScreen(in standardPlayerOverlayView: StandardPlayerOverlayView)
    
    @available(iOS 15.0, *)
    func onSelectQuality(in standardPlayerOverlayView: StandardPlayerOverlayView)
    @available(iOS 15.0, *)
    func onSelectRate(in standardPlayerOverlayView: StandardPlayerOverlayView)
    
    func onSelectRemoteDevice(in standardPlayerOverlayView: StandardPlayerOverlayView)
    
    func onQualitySelected(quality: VideoQuality, in standardPlayerOverlayView: StandardPlayerOverlayView)
    func onRateSelected(rate: Speed, in standardPlayerOverlayView: StandardPlayerOverlayView)
}

class StandardPlayerOverlayView: PlayerOverlayView {
    
    // MARK: Components
    private let fullScreenInfoContainer: UIStackView = UIStackView().forAutoLayout()
    private let closeButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    private let titleLabel: UILabel = UILabel().forAutoLayout()
    private let subtitleLabel: UILabel = UILabel().forAutoLayout()
    
    private let routePickerView: AVRoutePickerView = AVRoutePickerView().forAutoLayout() // NOTE: this is hidden on the standard overlay to enable airplay selection from the remote device button
    private let remoteDeviceButton: CastPlayerBarButton = CastPlayerBarButton().forAutoLayout()
    private let pipButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    
    private let infoLabel: UILabel = UILabel().forAutoLayout()
    
    private let goBackwardButton: PlayerPlaybackButton = PlayerPlaybackButton().forAutoLayout()
    private let playPauseButton: PlayerPlaybackButton = PlayerPlaybackButton().forAutoLayout()
    private let goForwardButton: PlayerPlaybackButton = PlayerPlaybackButton().forAutoLayout()
    
    private let rateButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    private let qualityButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    
    private let fullTimeLineView: FullTimeLineView = FullTimeLineView().forAutoLayout()
    
    private let fullScreenButton: PlayerBarButton = PlayerBarButton().forAutoLayout()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Internal Variables
    weak var delegate: StandardPlayerOverlayViewDelegate?
    
    // MARK: Private Properties
    // Variables
    private var subscribers: Set<AnyCancellable> = []
    
    // MARK: Actions
    func setQualityOptions(_ qualities: [VideoQuality]) {
        let actions = qualities.map { quality in
            UIAction(title: quality.resolution) { [weak self] _ in
                guard let self else { return }
                self.delegate?.onQualitySelected(quality: quality, in: self)
            }
        }
        let menu = UIMenu(title: VideoQuality.header, children: actions)
        qualityButton.menu = menu
    }
    
    func setDuration(_ duration: CMTime) {
        fullTimeLineView.setDuration(duration)
    }
    
    func setTitle(_ title: String?, subtitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
    
    func setPipButtonEnabled(_ enabled: Bool) {
        pipButton.isEnabled = enabled
    }
    
    func setFullScreenButtonVisibility(visible: Bool) {
        fullScreenButton.isHidden = !visible
    }
    
    func switchFullScreen(on isFullScreen: Bool) {
        fullScreenButton.setImage(.library(named: isFullScreen ? "Video/FullScreen/Exit" : "Video/FullScreen/Start"), for: .normal)
        playPauseButton.heightConstraintConstant = isFullScreen ? 68.0: 48.0
        fullScreenInfoContainer.isHidden = !isFullScreen
    }
    
    func switchToPlaying(_ playing: Bool) {
        playPauseButton.setImage(.library(named: playing ? "Video/Playback/Pause" : "Video/Playback/Play"), for: .normal)
    }
    
    func setProgressTime(_ time: CMTime, duration: CMTime) {
        fullTimeLineView.setProgressTime(time, duration: duration)
    }
    
    func setRate(_ rate: Speed) {
        rateButton.setImage(.library(named: rate.iconName), for: .normal)
    }
    
    func setQuality(_ quality: VideoQuality) {
        qualityButton.setTitle(quality.definition.buttonText, for: .normal)
        qualityButton.setImage(nil, for: .normal)
        var image: UIImage?
        if let iconName = quality.definition.iconName {
            image = .library(named: iconName)
        }
        qualityButton.setImage(image, for: .normal)
    }
    
    func triggerAirplaySelection()  {
        for subview in routePickerView.subviews {
            if let control = subview as? UIControl {
                control.sendActions(for: .touchUpInside) // Programmatically "tap" the button
                break
            }
        }
    }
    
    func setDevice(_ deviceName: String?) {
        guard let deviceName else {
            remoteDeviceButton.tintColor = .white
            infoLabel.attributedText = nil
            backgroundColor = .clear
            return
        }
        
        backgroundColor = .black.withAlphaComponent(0.6)
        remoteDeviceButton.tintColor = ImpulsePlayer.shared.appearance.accentColor
        
        let fullText = String(format: .library(for: "controls_connected_to_x"), deviceName)
        let attributedText = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: ImpulsePlayer.shared.appearance.p2.font
            ]
        )

        if let headerRange = fullText.range(of: deviceName) {
            let nsRange = NSRange(headerRange, in: fullText)
            attributedText.addAttribute(.font, value: ImpulsePlayer.shared.appearance.h4.font, range: nsRange)
        }
        infoLabel.attributedText = attributedText
    }
}

// MARK: User Actions
@objc private extension StandardPlayerOverlayView {
    
    func closePressed() {
        delegate?.onClosePressed(in: self)
    }
    
    func pictureInPicturePressed() {
        delegate?.onPictureInPicturePressed(in: self)
    }
    
    func goForwardPressed() {
        delegate?.onGoForwardPressed(in: self)
    }
    
    func playPausePressed() {
        delegate?.onPlayPausePressed(in: self)
    }
    
    func goBackwardPressed() {
        delegate?.onGoBackwardPressed(in: self)
    }
    
    @available(iOS 15.0, *)
    func selectQuality() {
        delegate?.onSelectQuality(in: self)
    }
    
    @available(iOS 15.0, *)
    func selectRate() {
        delegate?.onSelectRate(in: self)
    }
    
    func selectRemoteDevice() {
        delegate?.onSelectRemoteDevice(in: self)
    }
    
    func toggleFullScreen() {
        delegate?.onToggleFullScreen(in: self)
    }
}

// MARK: - Setup
private extension StandardPlayerOverlayView {
    
    func setup() {
        setupTopLayoutBars()
        setupCenterLayoutBar()
        setupBottomLayoutBars()
        
        setupObservers()
    }
    
    // MARK: Top Layout
    func setupTopLayoutBars() {
        setupTopLeadingLayoutBar()
        setupTopTrailingLayoutBar()
    }
    
    func setupTopLeadingLayoutBar() {
        setupFullScreenInfoContainer()
    }
    
    func setupFullScreenInfoContainer() {
        fullScreenInfoContainer.axis = .horizontal
        fullScreenInfoContainer.spacing = 8.0
        fullScreenInfoContainer.alignment = .center
        addControl(fullScreenInfoContainer, position: .topLeading)
        
        setupCloseButton()
        fullScreenInfoContainer.addArrangedSubview(closeButton)
        
        let infoContainer = setupInfoContainer()
        fullScreenInfoContainer.addArrangedSubview(infoContainer)
    }
    
    func setupCloseButton()  {
        closeButton.setImage(.library(named: "Back_Icon"), for: .normal)
        closeButton.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
    }
    
    func setupInfoContainer() -> UIStackView {
        let infoContainer = UIStackView().forAutoLayout()
        infoContainer.axis = .vertical
        infoContainer.spacing = 0
        infoContainer.alignment = .leading
        addControl(infoContainer, position: .topLeading)
        
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
        setupAirplayButton()
        setupRemoteDeviceButton()
        setupPictureInPictureButton()
    }
    
    func setupAirplayButton() {
        routePickerView.isHidden = true
        routePickerView.tintColor = .white
        routePickerView.prioritizesVideoDevices = true
        routePickerView.heightAnchor.constraint(equalToConstant: 20.0).isActive = true
        routePickerView.widthAnchor.constraint(equalTo: routePickerView.heightAnchor).isActive = true
        addControl(routePickerView, position: .topTrailing)
    }
    
    func setupRemoteDeviceButton() {
        remoteDeviceButton.addTarget(self, action: #selector(selectRemoteDevice), for: .touchUpInside)
        addControl(remoteDeviceButton, position: .topTrailing)
    }
    
    func setupPictureInPictureButton() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }
        
        let startImage: UIImage? = .library(named: "Video/PictureInPicture/Start")
        let stopImage: UIImage? = .library(named: "Video/PictureInPicture/Exit")
        
        pipButton.setImage(startImage, for: .normal)
        pipButton.setImage(stopImage, for: .selected)
        
        pipButton.addTarget(self, action: #selector(pictureInPicturePressed), for: .touchUpInside)
        pipButton.isHidden = !ImpulsePlayer.shared.settings.pictureInPictureEnabled
        addControl(pipButton, position: .topTrailing)
    }
    
    // MARK: Center Layout
    func setupCenterLayoutBar() {
        setupInfoLabel()
        setupGoBackwardButton()
        setupPlayPauseButton()
        setupGoForwardButton()
    }
    
    func setupInfoLabel() {
        infoLabel.font = ImpulsePlayer.shared.appearance.p1.font
        infoLabel.textColor = .white
        
        addControl(infoLabel, position: .info)
    }
    
    func setupGoBackwardButton() {
        goBackwardButton.setImage(.library(named: "Video/Playback/Replay"), for: .normal)
        goBackwardButton.addTarget(self, action: #selector(goBackwardPressed), for: .touchUpInside)
        goBackwardButton.heightConstraintConstant = 36.0
        
        addControl(goBackwardButton, position: .center)
    }
    
    func setupPlayPauseButton() {
        playPauseButton.setImage(.library(named: "Video/Playback/Play"), for: .normal)
        playPauseButton.addTarget(self, action: #selector(playPausePressed), for: .touchUpInside)
        
        addControl(playPauseButton, position: .center)
    }
    
    func setupGoForwardButton() {
        goForwardButton.setImage(.library(named: "Video/Playback/Forward"), for: .normal)
        goForwardButton.addTarget(self, action: #selector(goForwardPressed), for: .touchUpInside)
        goForwardButton.heightConstraintConstant = 36.0
        
        addControl(goForwardButton, position: .center)
    }
    
    // MARK: Bottom Layout
    func setupBottomLayoutBars() {
        setupFullTimeLineView()
        
        setupBottomLeadingLayoutBar()
        setupBottomTrailingLayoutBar()
    }
    
    func setupFullTimeLineView() {
        fullTimeLineView.delegate = self
        addControl(fullTimeLineView, position: .bottomTop)
    }
    
    func setupBottomLeadingLayoutBar() {
        setupQualityButton()
        setupRateButton()
    }
    
    func setupQualityButton() {
        // NOTE: Quality button becomes available when a video is loaded in
        
        if #available(iOS 15.0, *) {
            qualityButton.addTarget(self, action: #selector(selectQuality), for: .touchUpInside)
        } else {
            qualityButton.showsMenuAsPrimaryAction = true
        }
        addControl(qualityButton, position: .bottomBottomLeading)
    }
    
    func setupRateButton() {
        rateButton.setImage(.library(named: Speed._1.iconName), for: .normal)
        
        if #available(iOS 15.0, *) {
            self.rateButton.addTarget(self, action: #selector(selectRate), for: .touchUpInside)
        } else {
            let actions = Speed.allCases.map { rate in
                UIAction(title: "\(rate.speed)x") { [weak self] _ in
                    guard let self else { return }
                    self.delegate?.onRateSelected(rate: rate, in: self)
                }
            }
            let menu = UIMenu(title: Speed.header, children: actions)
            self.rateButton.menu = menu
            self.rateButton.showsMenuAsPrimaryAction = true
        }
        
        addControl(rateButton, position: .bottomBottomLeading)
    }
    
    func setupBottomTrailingLayoutBar() {
        setupFullScreenButton()
    }
    
    func setupFullScreenButton() {
        fullScreenButton.addTarget(self, action: #selector(toggleFullScreen), for: .touchUpInside)
        addControl(fullScreenButton, position: .bottomBottomTrailing)
    }
    
    // Observers
    func setupObservers() {
        setupSettingsObserver()
        setupAVObserver()
    }
    
    func setupSettingsObserver() {
        ImpulsePlayer.shared.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.pipButton.isHidden = !settings.pictureInPictureEnabled
            }
            .store(in: &subscribers)
    }
    
    func setupAVObserver() {
        setDevice(AVAudioSession.sharedInstance().checkIfConnectedToExternalDevice())
        
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setDevice(AVAudioSession.sharedInstance().checkIfConnectedToExternalDevice())
            }
            .store(in: &subscribers)
    }
}

extension StandardPlayerOverlayView: FullTimeLineViewDelegate {
    
    func onSeekBarChanged(value: Float, in timeLine: FullTimeLineView) {
        delegate?.onSeekBarChanged(value: value, in: self)
    }
    
    func onSeeking(value: Float, in timeLine: FullTimeLineView) {
        delegate?.onSeeking(value: value, in: self)
    }
}


import AVFoundation

extension AVAudioSession {
    
    func checkIfConnectedToExternalDevice() -> String? {
        do {
            try setActive(true) // Ensure the session is active
            
            // Check if there are outputs other than the built-in speaker
            for output in currentRoute.outputs {
                if output.portType != .builtInSpeaker {
                    print("Connected to: \(output.portName)")
                    return output.portName
                }
            }
            
            print("Not connected to any external device.")
        } catch {
            print("Error activating audio session: \(error)")
        }
        
        return nil
    }
}

