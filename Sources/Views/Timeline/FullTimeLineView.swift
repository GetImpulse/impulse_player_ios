import AVFoundation
import UIKit

@MainActor
protocol FullTimeLineViewDelegate: AnyObject {
    func onSeekBarChanged(value: Float, in timeLine: FullTimeLineView)
    func onSeeking(value: Float, in timeLine: FullTimeLineView)
}

@MainActor
class FullTimeLineView: UIView {

    // MARK: Components
    private let timeLine: PlayerTimeline = PlayerTimeline().forAutoLayout()
    private let currentTimeLabel: UILabel = UILabel().forAutoLayout()
    private let timeSeparatorLabel: UILabel = UILabel().forAutoLayout()
    private let durationLabel: UILabel = UILabel().forAutoLayout()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Internal Variables
    weak var delegate: FullTimeLineViewDelegate?
    
    // MARK: Private Properties
    // Constants
    private let timeLabelSpacing: CGFloat = 4.0

    // Variables
    private var timeWidthConstraint: NSLayoutConstraint!
    
    // MARK: Actions
    func setDuration(_ duration: CMTime) {
        let text = duration.toMinutesAndSeconds()
//        let durationMaxWidth = text.width(containerHeight: 1.0)
//
//        // NOTE: The maximum width of the time label is the items duration * 2 + spacing between items and a fault margin of 4.0
//        let maxWidth = durationMaxWidth * 2 + timeLabelSpacing * 2 + 4.0
//        timeWidthConstraint.constant = maxWidth
//        timeWidthConstraint.isActive = maxWidth > 0
        durationLabel.text = text
    }
    
    func setProgressTime(_ time: CMTime, duration: CMTime) {
        currentTimeLabel.text = time.toMinutesAndSeconds()
        let value = time.seconds / duration.seconds
        timeLine.value = Float(value)
    }
}

// MARK: - User Actions
@objc private extension FullTimeLineView {
    
    func seekBarChanged() {
        delegate?.onSeekBarChanged(value: timeLine.value, in: self)
    }
    
    func seeking() {
        delegate?.onSeeking(value: timeLine.value, in: self)
    }
}

// MARK: - Setup
private extension FullTimeLineView {
    
    func setup() {
        setupTimeLineLayout()
        setupTimeLineControls()
    }
    
    func setupTimeLineLayout() {
        let containingLayout = UIStackView().forAutoLayout()
        containingLayout.axis = .vertical
        containingLayout.spacing = 8.0
        containingLayout.alignment = .center
        containingLayout.distribution = .fill
        addSubview(containingLayout)
        
        NSLayoutConstraint.activate([
            containingLayout.leadingAnchor.constraint(equalTo: leadingAnchor),
            containingLayout.topAnchor.constraint(equalTo: topAnchor),
            trailingAnchor.constraint(equalTo: containingLayout.trailingAnchor),
            bottomAnchor.constraint(equalTo: containingLayout.bottomAnchor)
        ])
        
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
        timeTextLayout.setContentHuggingPriority(.required, for: .horizontal)
        
        timeTextLayout.addArrangedSubview(currentTimeLabel)
        timeTextLayout.addArrangedSubview(timeSeparatorLabel)
        timeTextLayout.addArrangedSubview(durationLabel)
    }
    
    func setupTimeLineControls() {
        setupTimeLine()
        setupCurrentTimeLabel()
        setupTimeSeparatorLabel()
        setupDurationLabel()
    }
    
    func setupTimeLine() {
        timeLine.addTarget(self, action: #selector(seekBarChanged), for: .valueChanged)
        timeLine.addTarget(self, action: #selector(seeking), for: [.touchUpInside, .touchUpOutside])
        timeLine.setColoredThumb()
    }
    
    func setupCurrentTimeLabel() {
        currentTimeLabel.text = CMTime.zero.toMinutesAndSeconds()
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
        durationLabel.text = CMTime.zero.toMinutesAndSeconds()
        durationLabel.font = ImpulsePlayer.shared.appearance.l7.font
        durationLabel.textColor = .white.withAlphaComponent(0.6)
    }

}
