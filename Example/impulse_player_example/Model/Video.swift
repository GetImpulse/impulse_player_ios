import Foundation

struct Video: Hashable {
    
    let title: String?
    let subtitle: String?
    let url: URL
    
    init(title: String?, subtitle: String? = nil, url: URL) {
        
        self.title = title
        self.subtitle = subtitle
        self.url = url
    }
}
