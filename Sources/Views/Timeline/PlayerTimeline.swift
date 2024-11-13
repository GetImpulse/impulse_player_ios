import UIKit

class PlayerTimeline: UISlider {
    
    // Customize the thumb size
    var outsideThumbSize: CGSize = CGSize(width: 44.0, height: 44.0)
    var customThumbSize: CGSize = CGSize(width: 12.0, height: 12)

    // Customize the track height
    var customTrackHeight: CGFloat = 2.0
    
    // Custom track colors
    var minimumTrackColor: UIColor = ImpulsePlayer.shared.appearance.accentColor
    var maximumTrackColor: UIColor = .white.withAlphaComponent(0.6)
    var thumbColor: UIColor = ImpulsePlayer.shared.appearance.accentColor

    // Override the track rectangle to adjust the track height
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let defaultRect = super.trackRect(forBounds: bounds)
        let customRect = CGRect(x: defaultRect.origin.x,
                                y: defaultRect.origin.y + (defaultRect.height - customTrackHeight) / 2,
                                width: defaultRect.width,
                                height: customTrackHeight)
        return customRect
    }

    // Override the thumb rectangle to adjust the thumb's size
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let difference = CGFloat(value * 2 - 1) * -1
        let defaultThumbRect = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        let customThumbRect = CGRect(x: defaultThumbRect.origin.x - (outsideThumbSize.width - defaultThumbRect.width) / 2 - (outsideThumbSize.width - customThumbSize.width) / 2.0 * difference,
                                     y: defaultThumbRect.origin.y - (outsideThumbSize.height - defaultThumbRect.height) / 2,
                                     width: outsideThumbSize.width,
                                     height: outsideThumbSize.height)
        return customThumbRect
    }
    
    // Override draw method to customize track colors
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        // Customize the minimum track (left side of the slider)
        self.minimumTrackTintColor = minimumTrackColor

        // Customize the maximum track (right side of the slider)
        self.maximumTrackTintColor = maximumTrackColor
    }
    
    // Set a colored thumb image
    func setColoredThumb() {
        // Create an image with the thumb color
        let thumbImage = createThumbImage(color: thumbColor, size: outsideThumbSize)
        self.setThumbImage(thumbImage, for: .normal)
    }

    // Helper method to create a colored UIImage
    private func createThumbImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(
                ovalIn: CGRect(
                    origin: .init(
                        x: (outsideThumbSize.width - customThumbSize.width) / 2.0,
                        y: (outsideThumbSize.height - customThumbSize.height) / 2.0
                    ),
                    size: customThumbSize)
            )
            color.setFill()
            path.fill()
        }
        return image
    }
}
