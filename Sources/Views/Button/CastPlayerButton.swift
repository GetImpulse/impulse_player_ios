import GoogleCast

class CastPlayerBarButton: PlayerBarButton {
    
    // MARK: Components
    private let castButton: GCKUICastButton = GCKUICastButton(frame: .zero).forAutoLayout()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Setup
private extension CastPlayerBarButton {
    
    func setup() {
        setupCastButton()
    }
    
    func setupCastButton() {
        castButton.tintColor = .white
        castButton.isUserInteractionEnabled = false
        addSubview(castButton)
        NSLayoutConstraint.activate([
            castButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8.0),
            castButton.topAnchor.constraint(equalTo: topAnchor, constant: 8.0),
            trailingAnchor.constraint(equalTo: castButton.trailingAnchor, constant: 8.0),
            bottomAnchor.constraint(equalTo: castButton.bottomAnchor, constant: 8.0)
        ])
    }
}
