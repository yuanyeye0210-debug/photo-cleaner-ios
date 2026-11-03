import XCTest
#if canImport(PhotoCleaner)
@testable import PhotoCleaner
#else
@testable import CleanCore
#endif

/// 滑动判定：左删右留上稍后，快甩也算数，斜着拖不算
final class SwipeLogicTests: XCTestCase {
    private func d(_ dx: Double, _ dy: Double, _ pdx: Double? = nil, _ pdy: Double? = nil) -> SwipeOutcome {
        SwipeLogic.decide(dx: dx, dy: dy, predictedDX: pdx ?? dx, predictedDY: pdy ?? dy)
    }

    func testSlowDragPastThreshold() {
        XCTAssertEqual(d(-130, 10), .delete)   // 左滑 = 删除
        XCTAssertEqual(d(130, -10), .keep)     // 右滑 = 保留
        XCTAssertEqual(d(5, -130), .later)     // 上滑 = 稍后再看
    }

    func testSlowDragShortOfThresholdSnapsBack() {
        XCTAssertEqual(d(-100, 0), .none)
        XCTAssertEqual(d(100, 0), .none)
        XCTAssertEqual(d(0, -100), .none)
    }

    func testFastFlickCounts() {
        XCTAssertEqual(d(-70, 5, -320, 20), .delete)
        XCTAssertEqual(d(70, 5, 320, 20), .keep)
        XCTAssertEqual(d(3, -70, 10, -400), .later)
    }

    func testFlickTooShortOrTooSlowDoesNotCount() {
        XCTAssertEqual(d(-40, 0, -400, 0), .none)   // 不到 60pt
        XCTAssertEqual(d(-70, 0, -90, 0), .none)    // 速度不够，预测落点没过 110
    }

    func testFlickReversingDirectionDoesNotCount() {
        XCTAssertEqual(d(70, 0, -300, 0), .none)
    }

    func testDiagonalAndDownwardIgnored() {
        XCTAssertEqual(d(-200, 150), .none)          // 斜着拖
        XCTAssertEqual(d(-80, 10, -300, 260), .none) // 快甩但预测方向斜
        XCTAssertEqual(d(0, 200, 0, 600), .none)     // 下滑不算
    }
}
