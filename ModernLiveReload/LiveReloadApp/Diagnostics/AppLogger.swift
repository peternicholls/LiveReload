import LiveReloadCore
import OSLog

enum AppLogger {
    private static let subsystem = "com.peternicholls.LiveReload.Modern"

    static func log(_ event: ActivityEvent) {
        let logger = Logger(subsystem: subsystem, category: event.category.rawValue)
        switch event.severity {
        case .debug: logger.debug("\(event.summary, privacy: .public)")
        case .info: logger.info("\(event.summary, privacy: .public)")
        case .warning: logger.warning("\(event.summary, privacy: .public)")
        case .error: logger.error("\(event.summary, privacy: .public)")
        }
    }
}
