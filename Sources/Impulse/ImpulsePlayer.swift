import Foundation
import Combine
import GoogleCast

@MainActor
public final class ImpulsePlayer: ObservableObject {
    
    private let castLogger: ImpulseCastLogger = ImpulseCastLogger()
    
    public static let shared: ImpulsePlayer = ImpulsePlayer()
    
    @Published public private(set) var appearance: ImpulsePlayerAppearance = ImpulsePlayerAppearance(accentColor: .library(named: "ImpulseAccent")!)
    @Published public private(set) var settings: ImpulsePlayerSettings = ImpulsePlayerSettings()
    
    private var subscriptions: Set<AnyCancellable> = []
    
    private init () {
        setup()
    }

    public static func setAppearance(appearance: ImpulsePlayerAppearance) {
        shared.appearance = appearance
    }
    
    public static func setSettings(settings: ImpulsePlayerSettings) {
        shared.settings = settings
    }
}

// MARK: Setup
private extension ImpulsePlayer {
    
    func setup() {
        setupSettingsObserver()
    }
    
    func setupSettingsObserver() {
        $settings
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.loadCastIfNeeded(settings.castReceiverApplicationId)
            }
            .store(in: &subscriptions)
    }
    
    func loadCastIfNeeded(_ applicationReceiverId: String?) {
        guard let applicationReceiverId, GCKCastContext.isSharedInstanceInitialized() == false else { return }
        
        // Set your receiver application ID.
        let options = GCKCastOptions(discoveryCriteria: GCKDiscoveryCriteria(applicationID: applicationReceiverId))
        options.physicalVolumeButtonsWillControlDeviceVolume = true

        // Set launch options
        let launchOptions = GCKLaunchOptions()
        launchOptions.androidReceiverCompatible = true
        options.launchOptions = launchOptions

        GCKCastContext.setSharedInstanceWith(options)
        GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true

        GCKLogger.sharedInstance().delegate = castLogger
    }
}
