import UIKit

extension Bundle {
        
    static var moduleOrCocoapod: Bundle {
#if SWIFT_PACKAGE // SPM
        return module
#else // CocoaPods
        let bundle = Bundle(for: ImpulsePlayer.self)
        if let resourceURL = bundle.url(forResource: "ImpulseResources", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceURL) {
            return resourceBundle
        } else {
            return bundle
        }
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
