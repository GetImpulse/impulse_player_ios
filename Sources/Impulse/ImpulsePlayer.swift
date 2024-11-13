import Foundation

@MainActor
public final class ImpulsePlayer: ObservableObject {
    
    public static let shared: ImpulsePlayer = ImpulsePlayer()
    
    @Published public private(set) var appearance: ImpulsePlayerAppearance = ImpulsePlayerAppearance(accentColor: .library(named: "ImpulseAccent")!)
    @Published public private(set) var settings: ImpulsePlayerSettings = ImpulsePlayerSettings()

    public static func setAppearance(appearance: ImpulsePlayerAppearance) {
        shared.appearance = appearance
    }
    
    public static func setSettings(settings: ImpulsePlayerSettings) {
        shared.settings = settings
    }
}
