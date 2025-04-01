import UIKit

class RemotePickerTableViewCell: UITableViewCell {

    private let iconWidth: CGFloat = 40.0
    private let imageSize: CGSize = CGSize(width: 24.0, height: 24.0)
    
    // MARK: Components
    private let containerView: UIView = {
        let view = UIView().forAutoLayout()
        view.layer.cornerRadius = 8.0
        view.layer.masksToBounds = true
        return view
    }()
    
    private let contentStackView: UIStackView = {
        let stackView = UIStackView().forAutoLayout()
        stackView.axis = .horizontal
        stackView.spacing = 16.0
        stackView.alignment = .center
        stackView.distribution = .fill
        return stackView
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView().forAutoLayout()
        imageView.tintColor = ImpulsePlayer.shared.appearance.accentColor
        imageView.contentMode = .scaleAspectFit
        
        imageView.widthAnchor.constraint(equalToConstant: imageSize.width).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: imageSize.height).isActive = true
        
        return imageView
    }()
    
    private lazy var iconImageViewContainer: UIView = {
        let view = UIView().forAutoLayout()
        view.backgroundColor = ImpulsePlayer.shared.appearance.accentColor.withAlphaComponent(0.1)
        view.layer.cornerRadius = 16.0
        view.layer.masksToBounds = true
        
        view.widthAnchor.constraint(equalToConstant: iconWidth).isActive = true
        view.heightAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        
        view.addSubview(iconImageView)
        iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        iconImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        return view
    }()
    
    private let titleLabel = {
        let label = UILabel().forAutoLayout()
        label.font = ImpulsePlayer.shared.appearance.p1.font
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentStackView.addArrangedSubview(iconImageViewContainer)
        contentStackView.addArrangedSubview(titleLabel)
        
        containerView.addSubview(contentStackView)
        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8.0),
            contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4.0),
            containerView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: 8.0),
            containerView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor, constant: 4.0)
        ])
        
        contentView.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16.0),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8.0),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 16.0),
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 8.0)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        containerView.backgroundColor = highlighted ?
            .library(named: "SelectionBackground") :
            .clear
    }
    
    func update(with viewModel: ViewModel) {
        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title
    }
}

extension RemotePickerTableViewCell {
    
    struct ViewModel {
        let icon: UIImage?
        let title: String?
    }
}
