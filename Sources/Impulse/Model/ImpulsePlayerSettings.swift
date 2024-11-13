import Foundation

public struct ImpulsePlayerSettings {
    let pictureInPictureEnabled: Bool
    
    public init(
        pictureInPictureEnabled: Bool = false
    ) {
        self.pictureInPictureEnabled = pictureInPictureEnabled
    }
}
