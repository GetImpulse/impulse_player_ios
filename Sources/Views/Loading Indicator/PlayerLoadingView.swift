import UIKit

class PlayerLoadingView: UIView {

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.image = .library(named: "Video/Playback/Spinner")
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Properties
    private var widthConstraint: NSLayoutConstraint?
    private var isAnimating: Bool = false {
        didSet { isHidden = hidesWhenStopped && !isAnimating }
    }
    
    // Internal
    /// *hidesWhenStopped* determines if the loading view is hidden when not animating
    var hidesWhenStopped: Bool = true {
        didSet { isHidden = hidesWhenStopped && !isAnimating }
    }
    
    var size: Size = .large {
        didSet { widthConstraint?.constant = size.value }
    }
    
    var color: UIColor = .white {
        didSet { imageView.tintColor = color }
    }
    
    // MARK: Functions
    func setLoadingImage(_ image: UIImage) {
        imageView.image = image
    }
    
    func startAnimating() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2)
        rotation.duration = 1 // One complete rotation every second
        rotation.isCumulative = true
        rotation.repeatCount = Float.infinity
        imageView.layer.add(rotation, forKey: "rotationAnimation")
        
        isAnimating = true
        isHidden = false
    }
    
    func stopAnimating() {
        imageView.layer.removeAnimation(forKey: "rotationAnimation")
        
        isAnimating = false
        isHidden = hidesWhenStopped
    }
}

extension PlayerLoadingView {
    
    enum Size {
        case small
        case large
        
        var value: CGFloat {
            switch self {
            case .small: 32.0
            case .large: 56.0
            }
        }
    }
}

// MARK: - Setup
private extension PlayerLoadingView {
    
    func setup() {
        backgroundColor = .clear

        addSubview(imageView)
        
        // Add constraints to center the imageView
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            imageView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            imageView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            imageView.heightAnchor.constraint(equalTo: widthAnchor)
        ])
        
        widthConstraint = imageView.heightAnchor.constraint(equalToConstant: size.value)
        widthConstraint?.isActive = true
    }
}
