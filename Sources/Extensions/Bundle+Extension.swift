import UIKit

extension Bundle {
        
    static var moduleOrCocoapod: Bundle {
#if SWIFT_PACKAGE // SPM
        return module
#else // CocoaPods
        return Bundle(for: ImpulsePlayer.self)
#endif
    }
    
    func getSupportedInterfaceOrientations() -> [UIInterfaceOrientationMask] {
        // Access the value for UISupportedInterfaceOrientations in Info.plist
        if let orientations = object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String] {
            
            // Map the array of orientation strings to UIInterfaceOrientationMask
            let supportedOrientations: [UIInterfaceOrientationMask] = orientations.compactMap { orientation in
                switch orientation {
                case "UIInterfaceOrientationPortrait":
                    return .portrait
                case "UIInterfaceOrientationPortraitUpsideDown":
                    return .portraitUpsideDown
                case "UIInterfaceOrientationLandscapeLeft":
                    return .landscapeLeft
                case "UIInterfaceOrientationLandscapeRight":
                    return .landscapeRight
                default:
                    return nil
                }
            }
            
            return supportedOrientations
        }
        
        return []
    }
}
