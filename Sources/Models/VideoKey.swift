import Foundation

struct VideoKey {
    
    public let identifier: String
    
    // NOTE: Using this method to create video identifiers returns a key which must be kept to determine if a picture in picture video can be placed back in its original container
    static func create(playerView: ImpulsePlayerView) -> VideoKey {
        return VideoKey(identifier: UUID().uuidString)
    }
}
