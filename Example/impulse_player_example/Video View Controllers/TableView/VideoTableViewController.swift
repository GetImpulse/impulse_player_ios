import UIKit
import ImpulsePlayer
import Foundation
import Combine

class VideoTableViewController: UITableViewController {

    private let videoCellReuseIdentifier = "VideoCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
}


extension VideoTableViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Settings.videos.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: videoCellReuseIdentifier) as? VideoCell else {
            fatalError("Could not dequeue VideoCell")
        }
        
        let video = Settings.videos[indexPath.row]
        cell.load(video: video, parent: self)
        
        return cell
    }
}

private extension VideoTableViewController {
    
    func setup() {
        tableView.register(VideoCell.self, forCellReuseIdentifier: videoCellReuseIdentifier)
        view.backgroundColor = .systemBackground
        
        customization()
    }
    
    func customization() {
        ImpulsePlayer.setAppearance(
            appearance: ImpulsePlayerAppearance(
                h3: ImpulsePlayerFont(
                    fontType: .customByName(fontName: "Inter-Regular_SemiBold"),
                    size: 16.0
                ),
                h4: ImpulsePlayerFont(
                    fontType: .customByName(fontName: "Inter-Regular_SemiBold"),
                    size: 14.0
                ),
                s1: ImpulsePlayerFont(
                    fontType: .customByName(fontName: "Inter-Regular"),
                    size: 12.0
                ),
                l4: ImpulsePlayerFont(
                    fontType: .customByName(fontName: "Inter-Regular"),
                    size: 14.0
                ),
                l7: ImpulsePlayerFont(
                    fontType: .customByName(fontName: "Inter-Regular"),
                    size: 10.0
                ),
                p1: ImpulsePlayerFont(
                    fontType: .customByName(fontName: "Inter-Regular"),
                    size: 16.0
                ),
                p2: ImpulsePlayerFont(
                    fontType: .customByName(fontName: "Inter-Regular"),
                    size: 14.0
                ),
                accentColor: .accent
            )
        )
    }
}
