import UIKit
import ImpulsePlayer

class MainViewController: UITableViewController {
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return "Examples"
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Settings.videos.count
	}
	
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "SimpleCell", for: indexPath)
        let video = Settings.videos[indexPath.row]
        cell.textLabel?.text = video.title
		return cell
	}
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let video = Settings.videos[indexPath.row]
        
        switch indexPath.row {
        case Settings.videos.count - 1: // NOTE: Last video shows the same video twice
            let vc = VideoViewController(video: video, secondVideo: video)
            present(vc, animated: true)
        default:
            let vc = VideoViewController(video: video, secondVideo: nil)
            present(vc, animated: true)
        }
    }
}
