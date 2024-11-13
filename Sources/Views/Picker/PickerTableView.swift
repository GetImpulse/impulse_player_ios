import UIKit

@MainActor
protocol PickerTableViewDelegate: AnyObject {
    func selectedItemInPickerView<T>(_ pickerView: PickerTableView<T>, item: T)
}

class PickerTableView<T: Equatable & CustomStringConvertible>: UITableViewController {
    
    private let header: String
    private let items: [T]
    
    private var selectedIndexPath: IndexPath?
    
    weak var delegate: PickerTableViewDelegate?
    
    init(header: String, items: [T], selectedIndex: Int? = nil) {
        self.header = header
        self.items = items
        if let selectedIndex {
            self.selectedIndexPath = IndexPath(item: selectedIndex, section: 0)
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init(header: String, items: [T], currentlySelectedItem: T?) {
        let selectedIndex: Int? = if let currentlySelectedItem {
            items.firstIndex(where: { $0 == currentlySelectedItem })
        } else {
            nil
        }
        self.init(header: header, items: items, selectedIndex: selectedIndex)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.selectRow(at: selectedIndexPath, animated: false, scrollPosition: .none)
    }
    
    // MARK: Tableview datasource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let item = items[indexPath.row]
        cell.textLabel?.text = item.description
        cell.selectionStyle = .none

        return cell
    }
    
    // MARK: TableView delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        delegate?.selectedItemInPickerView(self, item: item)
        self.dismiss(animated: true)
    }
}

private extension PickerTableView {
    
    func setup() {        
        tableView.register(PickerTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.estimatedRowHeight = 48.0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        
        setupHeader()
    }
    
    func setupHeader() {
        let headerContainer = UIView().forAutoLayout()
        
        let headerLabel = UILabel().forAutoLayout()
        headerLabel.font = ImpulsePlayer.shared.appearance.h3.font
        headerLabel.text = header
        headerContainer.addSubview(headerLabel)
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 45.0),
            headerContainer.trailingAnchor.constraint(equalTo: headerLabel.trailingAnchor, constant: 16.0),
            headerContainer.bottomAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16.0),
            headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16.0)
        ])
        
        let size = headerLabel.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width - 32, height: UIView.layoutFittingCompressedSize.height))
        headerContainer.frame.size = CGSize(width: tableView.bounds.width, height: size.height + 45.0 + 16.0)
        
        tableView.tableHeaderView = headerContainer
    }
}
