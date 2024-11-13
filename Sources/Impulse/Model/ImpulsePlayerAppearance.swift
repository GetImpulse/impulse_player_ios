import Foundation
import UIKit

public struct ImpulsePlayerAppearance {
    let h3: ImpulsePlayerFont
    let h4: ImpulsePlayerFont
    let s1: ImpulsePlayerFont
    let l4: ImpulsePlayerFont
    let l7: ImpulsePlayerFont
    let p1: ImpulsePlayerFont
    let p2: ImpulsePlayerFont
    let accentColor: UIColor
    
    public init(
        h3: ImpulsePlayerFont = ImpulsePlayerFont(fontType: .system(bold: true, italic: false), size: 16.0),
        h4: ImpulsePlayerFont = ImpulsePlayerFont(fontType: .system(bold: true, italic: false), size: 14.0),
        s1: ImpulsePlayerFont = ImpulsePlayerFont(size: 12),
        l4: ImpulsePlayerFont = ImpulsePlayerFont(size: 14),
        l7: ImpulsePlayerFont = ImpulsePlayerFont(size: 10),
        p1: ImpulsePlayerFont = ImpulsePlayerFont(size: 16),
        p2: ImpulsePlayerFont = ImpulsePlayerFont(size: 14),
        accentColor: UIColor = .white
    ) {
        self.h3 = h3
        self.h4 = h4
        self.s1 = s1
        self.l4 = l4
        self.l7 = l7
        self.p1 = p1
        self.p2 = p2
        self.accentColor = accentColor
    }
}
