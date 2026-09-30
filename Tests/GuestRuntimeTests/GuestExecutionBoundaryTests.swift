import XCTest
@testable import EeveeSpotify

final class GuestExecutionBoundaryTests: XCTestCase {
    func testNormalIOSBoundaryIsBlockedWithoutExecution() {
        let assessment = IOSStructuralExecutionBoundary().assess()
        guard case .blocked(let reason) = assessment.status else {
            return XCTFail("normal iOS execution must remain blocked")
        }
        XCTAssertFalse(reason.isEmpty)
        XCTAssertTrue(assessment.restrictions.contains { $0.contains("assinatura") })
    }
}
