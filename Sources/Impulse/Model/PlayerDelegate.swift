import Foundation

@MainActor
public protocol PlayerDelegate: AnyObject {
    func onReady(_ impulsePlayerView: ImpulsePlayerView)
    func onPlay(_ impulsePlayerView: ImpulsePlayerView)
    func onPause(_ impulsePlayerView: ImpulsePlayerView)
    func onFinish(_ impulsePlayerView: ImpulsePlayerView)
    func onError(_ impulsePlayerView: ImpulsePlayerView, message: String)
}
