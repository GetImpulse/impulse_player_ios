import UIKit
import ImpulsePlayer
import Foundation
import Combine

class VideoViewController: UIViewController {
    
    private let video: Video
    private let secondVideo: Video?
    
    init(video: Video, secondVideo: Video?) {
        self.video = video
        self.secondVideo = secondVideo
        super.init(nibName: nil, bundle: nil)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    private lazy var impulsePlayer: ImpulsePlayerView = { ImpulsePlayerView(parent: self) }()
    private lazy var impulsePlayerTwo: ImpulsePlayerView = { ImpulsePlayerView(parent: self) }()
}

private extension VideoViewController {
    
    func setup() {
        view.backgroundColor = .systemBackground
        
        impulsePlayer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(impulsePlayer)
        NSLayoutConstraint.activate([
            impulsePlayer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            impulsePlayer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            impulsePlayer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            impulsePlayer.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 9.0/16.0)
        ])
        
        if let secondVideo {
            impulsePlayerTwo.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(impulsePlayerTwo)
            NSLayoutConstraint.activate([
                impulsePlayerTwo.topAnchor.constraint(equalTo: impulsePlayer.bottomAnchor),
                impulsePlayerTwo.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                impulsePlayerTwo.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                impulsePlayerTwo.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 9.0/16.0)
            ])
            
            impulsePlayerTwo.load(
                title: secondVideo.title,
                subtitle: secondVideo.subtitle,
                url: secondVideo.url
            )
        }
        
        commands()
//        setters()
        listeners()
        settings()
        customization()
    }
    
    func commands() {
        impulsePlayer.load(title: nil, subtitle: nil, url: video.url)
        impulsePlayer.load(
            title: video.title,
            subtitle: video.subtitle,
            url: video.url
        )
        impulsePlayer.play()
        impulsePlayer.pause()
        impulsePlayer.seek(to: 0)
    }
    
    func getters() {
        // NOTE: All values are KVO observable
        _ = impulsePlayer.isPlaying // Bool, default `false`
        _ = impulsePlayer.state // PlayerState, default `.loading`
        _ = impulsePlayer.progress // TimeInterval, default `0.0`
        _ = impulsePlayer.duration // TimeInterval, default `0.0`
        _ = impulsePlayer.error // Error?, default `nil`
    }
    
    func setters() {
        impulsePlayer.removeButton(key: "autoplay")
        impulsePlayer.setButton(
            key: "autoplay",
            playerButton: PlayerButton(
                position: .topEnd,
                icon: .add,
                title: "Autoplay"
            ) {
                print("Auto play clicked")
            }
        )
    }
    
    func listeners() {
        impulsePlayer.delegate = self
        impulsePlayerTwo.delegate = self
    }
    
    func settings() {
        ImpulsePlayer.setSettings(
            settings: ImpulsePlayerSettings(
                pictureInPictureEnabled: true  // Default `false`
            )
        )
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

extension VideoViewController: PlayerDelegate {
    func onReady(_ impulsePlayerView: ImpulsePlayerView) {
        print("onReady")
    }
    
    func onPlay(_ impulsePlayerView: ImpulsePlayerView) {
        print("onPlay")
    }
    
    func onPause(_ impulsePlayerView: ImpulsePlayerView) {
        print("onPause")
    }
    
    func onFinish(_ impulsePlayerView: ImpulsePlayerView) {
        print("onFinish")
    }
    
    func onError(_ impulsePlayerView: ImpulsePlayerView, message: String) {
        print("onError: \(message)")
    }
}
