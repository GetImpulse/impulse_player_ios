import GoogleCast

final class ImpulseCastLogger: NSObject, GCKLoggerDelegate {
    
    private let kDebugLoggingEnabled: Bool = false
    
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        if (kDebugLoggingEnabled) {
            print(function + " \(level.rawValue) - " + message)
        }
    }
}

