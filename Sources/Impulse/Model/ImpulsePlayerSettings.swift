import Foundation

public struct ImpulsePlayerSettings {
    let pictureInPictureEnabled: Bool
    let castReceiverApplicationId: String?
    
    public init(
        pictureInPictureEnabled: Bool = false,
        castReceiverApplicationId: String? = nil
    ) {
        self.pictureInPictureEnabled = pictureInPictureEnabled
        self.castReceiverApplicationId = castReceiverApplicationId
    }
}
