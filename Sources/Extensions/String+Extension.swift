import Foundation

extension String {
    
    static func library(for key: String) -> String {
        return NSLocalizedString(key, bundle: .moduleOrCocoapod, comment: "")
    }
}
