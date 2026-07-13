import XCTest
@testable import LiveReloadApp
import LiveReloadCore

final class LiveReloadAppTests: XCTestCase {
    func testAppTargetLoads() {
        XCTAssertEqual(LiveReloadCoreVersion.schemaVersion, 1)
    }
}
