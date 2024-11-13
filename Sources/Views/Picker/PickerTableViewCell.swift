import UIKit

class PickerTableViewCell: UITableViewCell {

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
        
        textLabel?.font = ImpulsePlayer.shared.appearance.p1.font
        
        contentView.addSubview(radioButton)
        NSLayoutConstraint.activate([
            radioButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8.0),
            radioButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16.0),
            radioButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8.0),
            radioButton.widthAnchor.constraint(equalToConstant: 32.0),
            radioButton.heightAnchor.constraint(equalToConstant: 32.0)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        updateRadioButtonState(isSelected: selected)
    }
    
    private func updateRadioButtonState(isSelected: Bool) {
        radioButton.isSelected = isSelected
    }
}
