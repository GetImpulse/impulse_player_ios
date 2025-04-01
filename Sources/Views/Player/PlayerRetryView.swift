import UIKit

@MainActor
protocol PlayerRetryViewDelegate: AnyObject {
    func onRetryPressed(in playerRetryView: PlayerRetryView)
}

class PlayerRetryView: UIView {
    
    // MARK: Components
    private let retryContainer: UIStackView = UIStackView().forAutoLayout()
    private let retryLabel: UILabel = UILabel().forAutoLayout()
    private let retryErrorCodeLabel: UILabel = UILabel().forAutoLayout()
    private let retryButton: UIButton = UIButton(type: .roundedRect).forAutoLayout()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Internal Variables
    weak var delegate: PlayerRetryViewDelegate?
    
    // MARK: Internal Functions
    func update(code: Int?) {
        if let code {
            retryErrorCodeLabel.text = String(format: .library(for: "controls_error_x"), "\(code)")
            retryContainer.isHidden = false
        } else {
            retryContainer.isHidden = true
        }
    }
}

// MARK: - Actions
@objc private extension PlayerRetryView {
    
    func retryPressed() {
        delegate?.onRetryPressed(in: self)
    }
}

// MARK: - Setup
private extension PlayerRetryView {
    
    func setup() {
        setupRetryContainer()
    }
    
    func setupRetryContainer() {
        retryContainer.isHidden = true
        retryContainer.axis = .vertical
        retryContainer.spacing = 16.0
        retryContainer.alignment = .center
        retryContainer.distribution = .fill
        addSubview(retryContainer)
        NSLayoutConstraint.activate([
            retryContainer.topAnchor.constraint(equalTo: topAnchor),
            retryContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            retryContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            retryContainer.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
        
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
        retryLabel.text = .library(for: "controls_error_title")
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
        retryButton.addTarget(self, action: #selector(retryPressed), for: .touchUpInside)
        retryContainer.addArrangedSubview(retryButton)
        retryButton.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
    }
}
