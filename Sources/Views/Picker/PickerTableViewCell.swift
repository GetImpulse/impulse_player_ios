import UIKit

class PickerTableViewCell: UITableViewCell {

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
    
    private let titleLabel = {
        let label = UILabel().forAutoLayout()
        label.font = ImpulsePlayer.shared.appearance.p1.font
        return label
    }()
    
    let radioButton: UIButton = {
        let button = UIButton(type: .custom).forAutoLayout()
        button.setImage(.library(named: "Picker/BTN radio unselected"), for: .normal)
        button.setImage(.library(named: "Picker/BTN radio"), for: .selected)
        button.imageView?.tintColor = ImpulsePlayer.shared.appearance.accentColor
        button.isUserInteractionEnabled = false
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(radioButton)
        NSLayoutConstraint.activate([
            radioButton.widthAnchor.constraint(equalToConstant: 32.0),
            radioButton.heightAnchor.constraint(equalToConstant: 32.0)
        ])
        
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
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        updateRadioButtonState(isSelected: selected)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        containerView.backgroundColor = highlighted ?
            .library(named: "SelectionBackground") :
            .clear
    }
    
    private func updateRadioButtonState(isSelected: Bool) {
        radioButton.isSelected = isSelected
    }
    
    func update(title: String) {
        titleLabel.text = title
    }
}
