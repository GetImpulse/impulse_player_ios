import UIKit

public struct ImpulsePlayerFont {
    
    let fontType: FontType
    let size: CGFloat
    
    public init(fontType: FontType = .system(bold: false, italic: false), size: CGFloat) {
        self.fontType = fontType
        self.size = size
    }
    
    var font: UIFont {
        switch fontType {
        case .customByName(let fontName):
            return UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
        case .customByFamily(let familyName, let isBold, let isItalic):
            return UIFont.custom(descriptor: UIFontDescriptor(name: familyName, size: size), addBold: isBold, addItalic: isItalic)
        case .system(let isBold, let isItalic):
            return UIFont.custom(descriptor: UIFont.systemFont(ofSize: size).fontDescriptor, addBold: isBold, addItalic: isItalic)
        }
    }
}

extension UIFont {
    
    static func custom(descriptor: UIFontDescriptor, addBold: Bool, addItalic: Bool) -> UIFont {
        // Apply bold trait if specified
        var traits: UIFontDescriptor.SymbolicTraits = []
        if addBold {
            traits.insert(.traitBold)
        }
        
        // Apply italic trait if specified
        if addItalic {
            traits.insert(.traitItalic)
        }
        
        return UIFont(descriptor: descriptor.withSymbolicTraits(traits) ?? descriptor, size: descriptor.pointSize)
    }
}

public extension ImpulsePlayerFont {
    
    public enum FontType {
        case customByName(fontName: String)
        case customByFamily(familyName: String, bold: Bool, italic: Bool)
        case system(bold: Bool, italic: Bool)
    }
}
