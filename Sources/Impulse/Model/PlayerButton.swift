import UIKit

public struct PlayerButton {
    
    let position: Position
    let icon: UIImage
    let title: String
    let action: () -> Void
    
    public init(position: Position, icon: UIImage, title: String, action: @escaping () -> Void) {
        self.position = position
        self.icon = icon
        self.title = title
        self.action = action
    }
}

public extension PlayerButton {
    
    public enum Position {
        case topEnd
        case bottomStart
        case bottomEnd
    }
}
