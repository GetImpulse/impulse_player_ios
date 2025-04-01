import UIKit
import GoogleCast
import Combine

@MainActor
protocol RemotePickerTableViewDelegate: AnyObject {
    func selectedItemInPickerView(_ pickerView: RemotePickerTableView, item: RemoteDevice)
}

class RemotePickerTableView: UITableViewController {
    
    // MARK: DI
    private let header: String
    
    init(header: String) {
        self.header = header
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Variables
    weak var delegate: RemotePickerTableViewDelegate?
    
    // MARK: Private Variables
    private var items: [RemoteDevice] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
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
        cell.selectionStyle = .none
        
        guard let remotePickerTableViewCell = cell as? RemotePickerTableViewCell else {
            return cell
        }
        
        let item = items[indexPath.row]
        remotePickerTableViewCell.update(with: .init(icon: .library(named: item.iconName), title: item.description))
        return remotePickerTableViewCell
    }
    
    // MARK: TableView delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        delegate?.selectedItemInPickerView(self, item: item)
        self.dismiss(animated: true)
    }
}

private extension RemotePickerTableView {
    
    func setup() {
        setupLayout()
        setupObservers()
    }
    
    func setupLayout() {
        tableView.register(RemotePickerTableViewCell.self, forCellReuseIdentifier: "cell")
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
            headerContainer.trailingAnchor.constraint(equalTo: headerLabel.trailingAnchor, constant: 24.0),
            headerContainer.bottomAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16.0),
            headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 24.0)
        ])
        
        let size = headerLabel.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width - 48.0, height: UIView.layoutFittingCompressedSize.height))
        headerContainer.frame.size = CGSize(width: tableView.bounds.width, height: size.height + 45.0 + 16.0)
        
        tableView.tableHeaderView = headerContainer
    }
    
    func setupObservers() {
        GCKCastContext.sharedInstance().discoveryManager.add(self)
        GCKCastContext.sharedInstance().sessionManager.add(self)
        
        updateDeviceList()
    }
}

private extension RemotePickerTableView {
    
    func updateDeviceList() {
        var devices: [RemoteDevice] = []
        let sessionManager = GCKCastContext.sharedInstance().sessionManager
        if sessionManager.hasConnectedSession() {
            devices.append(.thisDevice)
        }
        
        devices.append(.airplay)
        
        let discoveryManager = GCKCastContext.sharedInstance().discoveryManager
        discoveryManager.startDiscovery()
        let deviceCount = discoveryManager.deviceCount
        if deviceCount > 0 {
            (0..<deviceCount).forEach { index in
                let device = discoveryManager.device(at: index)
                devices.append(.cast(device: device))
            }
        }
        
        items = devices
        tableView.reloadData()
    }
}

extension RemotePickerTableView: @preconcurrency GCKDiscoveryManagerListener {
    
    func didUpdateDeviceList() {
        Task { @MainActor in
            updateDeviceList()
        }
    }
}

extension RemotePickerTableView: @preconcurrency GCKSessionManagerListener {
    
    func sessionManager(_ sessionManager: GCKSessionManager, session: GCKSession, didUpdate device: GCKDevice) {
        Task { @MainActor in
            updateDeviceList()
        }
    }
}
