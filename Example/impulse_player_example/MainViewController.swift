import UIKit
import ImpulsePlayer

class MainViewController: UIViewController {
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    @IBAction func showVideos(_ sender: Any) {
        let vc = VideoViewController()
        present(vc, animated: true)
    }
}

private extension MainViewController {
    
    func setup() {
        settings()
    }
    
    func settings() {
        ImpulsePlayer.setSettings(
            settings: ImpulsePlayerSettings(
                pictureInPictureEnabled: true,  // Default `false`
                castReceiverApplicationId: "01128E51" // Cast receiver application id of the cast app; Default `null` (disabled)
            )
        )
    }
}
