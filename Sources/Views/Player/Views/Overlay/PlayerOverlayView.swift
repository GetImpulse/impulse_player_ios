import UIKit

class PlayerOverlayView: UIView {
    
    // MARK: Components
    private let topLayout: UIStackView = UIStackView().forAutoLayout()
    private let topLeadingToolBar: UIStackView = UIStackView().forAutoLayout()
    private let topTrailingToolBar: UIStackView = UIStackView().forAutoLayout()
    
    private let infoLayout: UIStackView = UIStackView().forAutoLayout()
    private let centerLayout: UIView = UIView().forAutoLayout()
    private let centerPlaybackControlBar: UIStackView = UIStackView().forAutoLayout()
    
    private let bottomLayout: UIStackView = UIStackView().forAutoLayout()
    private let bottomTopToolBar: UIStackView = UIStackView().forAutoLayout()
    private let bottomLeadingToolBar: UIStackView = UIStackView().forAutoLayout()
    private let bottomTrailingToolBar: UIStackView = UIStackView().forAutoLayout()
    
    // MARK: Constraints
    private var verticalLayoutPaddingConstraints: [NSLayoutConstraint] = []
    private var horizontalLayoutPaddingConstraints: [NSLayoutConstraint] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PlayerOverlayView {
    
    enum ControlPosition {
        case topLeading
        case topTrailing
        case info
        case center
        case bottomTop
        case bottomBottomLeading
        case bottomBottomTrailing
    }
}

extension PlayerOverlayView {
 
    func addControl(_ view: UIView, position: ControlPosition) {
        switch position {
        case .topLeading:
            topLeadingToolBar.addArrangedSubview(view)
        case .topTrailing:
            topTrailingToolBar.addArrangedSubview(view)
        case .info:
            infoLayout.addArrangedSubview(view)
        case .center:
            centerPlaybackControlBar.addArrangedSubview(view)
        case .bottomTop:
            bottomTopToolBar.addArrangedSubview(view)
        case .bottomBottomLeading:
            bottomLeadingToolBar.addArrangedSubview(view)
        case .bottomBottomTrailing:
            bottomTrailingToolBar.addArrangedSubview(view)
        }
    }
    
    func setPadding(horizontal: CGFloat? = nil, vertical: CGFloat? = nil) {
        if let horizontal {
            horizontalLayoutPaddingConstraints.forEach { $0.constant = horizontal }
        }
        
        if let vertical {
            verticalLayoutPaddingConstraints.forEach { $0.constant = vertical }
        }
    }
}

// MARK: - Setup
private extension PlayerOverlayView {
    
    func setup() {
        setupLayout()
    }
    
    func setupLayout() {
        let layout = UIStackView().forAutoLayout()
        layout.axis = .vertical
        layout.spacing = 8.0
        layout.distribution = .equalSpacing
        layout.alignment = .center
        addSubview(layout)
        
        verticalLayoutPaddingConstraints = [
            layout.topAnchor.constraint(equalTo: topAnchor, constant: 8.0),
            bottomAnchor.constraint(equalTo: layout.bottomAnchor, constant: 8.0)
        ]
        horizontalLayoutPaddingConstraints = [
            trailingAnchor.constraint(equalTo: layout.trailingAnchor, constant: 16.0),
            layout.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16.0)
        ]
        [verticalLayoutPaddingConstraints, horizontalLayoutPaddingConstraints].flatMap { $0 }.forEach { $0.isActive = true }
        
        layout.addArrangedSubview(topLayout)
        topLayout.widthAnchor.constraint(equalTo: layout.widthAnchor).isActive = true
        topLayout.setContentHuggingPriority(.required, for: .vertical)
        setupTopLayout()
        
        layout.addArrangedSubview(bottomLayout)
        bottomLayout.widthAnchor.constraint(equalTo: layout.widthAnchor).isActive = true
        bottomLayout.setContentHuggingPriority(.required, for: .vertical)
        setupBottomLayout()
        
        addSubview(centerLayout)
        NSLayoutConstraint.activate([
            centerLayout.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerLayout.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setupCenterLayout()
    }
    
    // MARK: Top Layout
    func setupTopLayout() {
        topLayout.axis = .horizontal
        topLayout.spacing = 0
        topLayout.alignment = .center
        topLayout.distribution = .equalSpacing
        
        topLeadingToolBar.axis = .horizontal
        topLeadingToolBar.spacing = 8.0
        topLeadingToolBar.alignment = .center
        topLeadingToolBar.distribution = .fill
        topLayout.addArrangedSubview(topLeadingToolBar)
        
        topTrailingToolBar.axis = .horizontal
        topTrailingToolBar.spacing = 8.0
        topTrailingToolBar.alignment = .center
        topTrailingToolBar.distribution = .fill
        topLayout.addArrangedSubview(topTrailingToolBar)
    }
    
    // MARK: Center Layout
    func setupCenterLayout() {
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
        
        setupInfoLayout()
    }
    
    func setupInfoLayout() {
        infoLayout.axis = .horizontal
        infoLayout.spacing = 32.0
        infoLayout.alignment = .center
        infoLayout.distribution = .fill
        addSubview(infoLayout)
        
        NSLayoutConstraint.activate([
            infoLayout.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16.0),
            infoLayout.centerXAnchor.constraint(equalTo: centerLayout.centerXAnchor),
            trailingAnchor.constraint(greaterThanOrEqualTo: infoLayout.trailingAnchor, constant: 16.0),
            infoLayout.bottomAnchor.constraint(equalTo: centerLayout.topAnchor, constant: -8.0),
        ])
    }
    
    // MARK: Bottom Layout
    func setupBottomLayout() {
        bottomLayout.axis = .vertical
        bottomLayout.spacing = 0
        bottomLayout.alignment = .center
        bottomLayout.distribution = .fill
        
        bottomTopToolBar.axis = .horizontal
        bottomTopToolBar.spacing = 8.0
        bottomTopToolBar.alignment = .center
        bottomTopToolBar.distribution = .fill
        bottomLayout.addArrangedSubview(bottomTopToolBar)
        bottomTopToolBar.widthAnchor.constraint(equalTo: bottomLayout.widthAnchor).isActive = true
        
        let bottomBottomLayout = UIStackView().forAutoLayout()
        bottomBottomLayout.axis = .horizontal
        bottomBottomLayout.spacing = 0
        bottomBottomLayout.alignment = .center
        bottomBottomLayout.distribution = .equalSpacing
        bottomLayout.addArrangedSubview(bottomBottomLayout)
        bottomBottomLayout.widthAnchor.constraint(equalTo: bottomLayout.widthAnchor).isActive = true
        
        bottomLeadingToolBar.axis = .horizontal
        bottomLeadingToolBar.spacing = 8.0
        bottomLeadingToolBar.alignment = .center
        bottomLeadingToolBar.distribution = .fill
        bottomBottomLayout.addArrangedSubview(bottomLeadingToolBar)
        
        bottomTrailingToolBar.axis = .horizontal
        bottomTrailingToolBar.spacing = 8.0
        bottomTrailingToolBar.alignment = .center
        bottomTrailingToolBar.distribution = .fill
        bottomBottomLayout.addArrangedSubview(bottomTrailingToolBar)
    }
}
