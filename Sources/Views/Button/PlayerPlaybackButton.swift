import UIKit

class PlayerPlaybackButton: UIButton {
    
    var heightConstraintConstant: CGFloat = 64.0 {
        didSet {
            updateCornerRadius()
            heightAnchorConstraint?.constant = heightConstraintConstant
        }
    }
    
    private var heightAnchorConstraint: NSLayoutConstraint?

    private let normalBackgroundColor = UIColor.black.withAlphaComponent(0.2)
    private let pressedBackgroundColor = UIColor.black.withAlphaComponent(0.3)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        backgroundColor = normalBackgroundColor
        
        addTarget(self, action: #selector(didPressDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(didRelease), for: [.touchUpInside, .touchCancel, .touchDragExit])
        
        imageEdgeInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
        
        imageView?.contentMode = .scaleAspectFit
        tintColor = .white
        
        heightAnchorConstraint = heightAnchor.constraint(equalToConstant: heightConstraintConstant)
        heightAnchorConstraint?.isActive = true
        
        widthAnchor.constraint(equalTo: heightAnchor).isActive = true
    
        updateCornerRadius()
    }
    
    private func updateCornerRadius() {
        layer.cornerRadius = heightConstraintConstant / 2
        layer.masksToBounds = true
    }
    
    @objc private func didPressDown() {
        backgroundColor = pressedBackgroundColor
    }

    @objc private func didRelease() {
        backgroundColor = normalBackgroundColor
    }
}
