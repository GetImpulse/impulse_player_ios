import UIKit

extension UIImage {
    
    static func library(named: String) -> UIImage? {
        return UIImage(named: named, in: .moduleOrCocoapod, compatibleWith: nil)
    }
}
