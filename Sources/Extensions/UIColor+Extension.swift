import UIKit

extension UIColor {
    
    static func library(named: String) -> UIColor? {
        return UIColor(named: named, in: .moduleOrCocoapod, compatibleWith: nil)
    }
}
