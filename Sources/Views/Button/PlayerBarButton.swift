import UIKit

class PlayerBarButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {        
        imageEdgeInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
        imageView?.contentMode = .scaleAspectFit
        titleLabel?.font = UIFont.systemFont(ofSize: 11.0, weight: .semibold)
        tintColor = .white
        heightAnchor.constraint(equalToConstant: 36.0).isActive = true
        widthAnchor.constraint(greaterThanOrEqualTo: heightAnchor).isActive = true
    }
}
