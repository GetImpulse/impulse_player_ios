import UIKit
import ImpulsePlayer
import Foundation
import Combine

class VideoViewController: UIViewController {
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private lazy var contentStackView: UIStackView = {
        let contentStackView = UIStackView(arrangedSubviews: [impulsePlayer, impulsePlayerTwo, impulsePlayerThree, impulsePlayerFour])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 8.0
        contentStackView.alignment = .fill
        return contentStackView
    }()
    
    
    private lazy var impulsePlayer: ImpulsePlayerView = { ImpulsePlayerView(parent: self) }()
    private lazy var impulsePlayerTwo: ImpulsePlayerView = { ImpulsePlayerView(parent: self) }()
    private lazy var impulsePlayerThree: ImpulsePlayerView = { ImpulsePlayerView(parent: self) }()
    private lazy var impulsePlayerFour: ImpulsePlayerView = { ImpulsePlayerView(parent: self) }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
}

private extension VideoViewController {
    
    func setup() {
        setupLayout()
        
        view.backgroundColor = .systemBackground
        
        let videoOne = Settings.videos[0]
        impulsePlayer.setCastEnabled(false)
        impulsePlayer.load(
            title: videoOne.title,
            subtitle: "Video 1 subtitle",
            url: videoOne.url
        )
        
        let videoTwo = Settings.videos[1]
        impulsePlayerTwo.load(
            title: videoTwo.title,
            subtitle: "Video 2 subtitle",
            url: videoTwo.url
        )
        
        let videoThree = Settings.videos[2]
        impulsePlayerThree.load(
            title: videoThree.title,
            subtitle: "Video 3 subtitle",
            url: videoThree.url
        )
        
        impulsePlayerFour.load(url: URL(string: "http://localhost")!)
        
//        commands()
//        getters()
//        setters()
        listeners()
        customization()
    }
    
    func setupLayout() {
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        
        scrollView.addSubview(contentStackView)
        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        NSLayoutConstraint.activate([
            impulsePlayer.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 9.0/16.0),
            impulsePlayerTwo.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 9.0/16.0),
            impulsePlayerThree.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 9.0/16.0),
            impulsePlayerFour.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 9.0/16.0)
        ])
    }
    
    func commands() {
        impulsePlayer.load(
            title: "Title",
            subtitle: "Subtitle",
            url: URL(string: "url")!
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
