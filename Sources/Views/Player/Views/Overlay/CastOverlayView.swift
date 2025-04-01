import UIKit
import AVKit
import GoogleCast
import Combine

@MainActor
protocol CastOverlayViewDelegate: AnyObject {
    
    func onGoForwardPressed(in castOverlayView: CastOverlayView)
    func onPlayPausePressed(in castOverlayView: CastOverlayView)
    func onGoBackwardPressed(in castOverlayView: CastOverlayView)
    func onSelectRemoteDevice(in castOverlayView: CastOverlayView)
    
    func onSeekBarChanged(value: Float, in castOverlayView: CastOverlayView)
    func onSeeking(value: Float, in castOverlayView: CastOverlayView)
}

class CastOverlayView: PlayerOverlayView {
    
    // MARK: Components
    private let remoteDeviceButton: CastPlayerBarButton = CastPlayerBarButton().forAutoLayout()
    private let infoLabel: UILabel = UILabel().forAutoLayout()
    
    private let goBackwardButton: PlayerPlaybackButton = PlayerPlaybackButton().forAutoLayout()
    private let playPauseButton: PlayerPlaybackButton = PlayerPlaybackButton().forAutoLayout()
    private let goForwardButton: PlayerPlaybackButton = PlayerPlaybackButton().forAutoLayout()
    
    private let fullTimeLineView: FullTimeLineView = FullTimeLineView().forAutoLayout()
    private let loadingActivity: PlayerLoadingView = PlayerLoadingView().forAutoLayout()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Internal Variables
    weak var delegate: CastOverlayViewDelegate?
    
    // MARK: Actions
    func switchPlayerState(_ state: GCKMediaPlayerState?) {
        // The play pause button is visible when the state is either paused or playing
        infoLabel.isVisible = state == .paused || state == .playing
        
        goForwardButton.isVisible = state == .paused || state == .playing
        playPauseButton.isVisible = state == .paused || state == .playing || state == nil
        goBackwardButton.isVisible = state == .paused || state == .playing
        
        fullTimeLineView.isVisible = state == .paused || state == .playing
        
        switch state {
        case .none, .unknown, .idle, .paused:
            playPauseButton.setImage(.library(named: "Video/Playback/Play"), for: .normal)
            loadingActivity.stopAnimating()
        case .playing:
            playPauseButton.setImage(.library(named: "Video/Playback/Pause"), for: .normal)
            loadingActivity.stopAnimating()
        case .buffering, .loading:
            loadingActivity.startAnimating()
        }
    }
    
    func setDuration(_ duration: CMTime) {
        fullTimeLineView.setDuration(duration)
    }
    
    func setProgressTime(_ time: CMTime, duration: CMTime) {
        fullTimeLineView.setProgressTime(time, duration: duration)
    }
    
    func setDevice(_ device: GCKDevice?) {
        let castText = device?.friendlyName ?? "Chromecast"
        let fullText = String(format: .library(for: "controls_connected_to_x"), castText)
        let attributedText = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: ImpulsePlayer.shared.appearance.p2.font
            ]
        )

        if let headerRange = fullText.range(of: castText) {
            let nsRange = NSRange(headerRange, in: fullText)
            attributedText.addAttribute(.font, value: ImpulsePlayer.shared.appearance.h4.font, range: nsRange)
        }
        infoLabel.attributedText = attributedText
    }
}

// MARK: User Actions
@objc private extension CastOverlayView {
    
    func goForwardPressed() {
        delegate?.onGoForwardPressed(in: self)
    }
    
    func playPausePressed() {
        delegate?.onPlayPausePressed(in: self)
    }
    
    func goBackwardPressed() {
        delegate?.onGoBackwardPressed(in: self)
    }
    
    func selectRemoteDevice() {
        delegate?.onSelectRemoteDevice(in: self)
    }
}

// MARK: - Setup
private extension CastOverlayView {
    
    func setup() {
        backgroundColor = .black.withAlphaComponent(0.6)
        
        setupRemoteDeviceButton()
        
        setupGoBackwardButton()
        setupPlayPauseButton()
        setupGoForwardButton()
        
        setupInfoLabel()
        setupFullTimeLineView()
        
        setupLoadingActivity()
        
        loadingActivity.startAnimating()
    }
    
    func setupRemoteDeviceButton() {
        remoteDeviceButton.addTarget(self, action: #selector(selectRemoteDevice), for: .touchUpInside)
        remoteDeviceButton.tintColor = ImpulsePlayer.shared.appearance.accentColor
        
        addControl(remoteDeviceButton, position: .topTrailing)
    }
    
    func setupGoBackwardButton() {
        goBackwardButton.isHidden = true
        goBackwardButton.setImage(.library(named: "Video/Playback/Replay"), for: .normal)
        goBackwardButton.addTarget(self, action: #selector(goBackwardPressed), for: .touchUpInside)
        goBackwardButton.heightConstraintConstant = 36.0
        
        addControl(goBackwardButton, position: .center)
    }
    
    func setupPlayPauseButton() {
        playPauseButton.isHidden = true
        playPauseButton.setImage(.library(named: "Video/Playback/Play"), for: .normal)
        playPauseButton.addTarget(self, action: #selector(playPausePressed), for: .touchUpInside)
        
        addControl(playPauseButton, position: .center)
    }
    
    func setupGoForwardButton() {
        goForwardButton.isHidden = true
        goForwardButton.setImage(.library(named: "Video/Playback/Forward"), for: .normal)
        goForwardButton.addTarget(self, action: #selector(goForwardPressed), for: .touchUpInside)
        goForwardButton.heightConstraintConstant = 36.0
        
        addControl(goForwardButton, position: .center)
    }
    
    func setupInfoLabel() {
        infoLabel.isHidden = true
        infoLabel.font = ImpulsePlayer.shared.appearance.p1.font
        infoLabel.textColor = .white
        
        addControl(infoLabel, position: .info)
    }
    
    func setupFullTimeLineView() {
        fullTimeLineView.isHidden = true
        fullTimeLineView.delegate = self
        
        addControl(fullTimeLineView, position: .bottomTop)
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
}

// MARK: Time Line Delegate
extension CastOverlayView: FullTimeLineViewDelegate {
    
    func onSeekBarChanged(value: Float, in timeLine: FullTimeLineView) {
        delegate?.onSeekBarChanged(value: value, in: self)
    }
    
    func onSeeking(value: Float, in timeLine: FullTimeLineView) {
        delegate?.onSeeking(value: value, in: self)
    }
}
