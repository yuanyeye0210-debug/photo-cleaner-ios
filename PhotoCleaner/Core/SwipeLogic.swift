import Foundation

/// 滑动卡片松手时的判定（纯逻辑，方便单测）
/// 左滑 = 标记删除，右滑 = 保留，上滑 = 稍后再看
enum SwipeOutcome: Equatable {
    case delete, keep, later, none
}

enum SwipeLogic {
    /// 慢慢拖：要拖过这么远才算
    static let threshold: Double = 110
    /// 快速甩：至少拖了这么远，并且按速度预测的落点越过 threshold
    static let flickMinimum: Double = 60
    /// 方向要明显：主方向是另一个方向的 1.5 倍以上
    static let dominance: Double = 1.5

    /// - Parameters:
    ///   - dx, dy: 松手时实际拖动的距离（pt，向右/向下为正）
    ///   - predictedDX, predictedDY: 按速度预测的落点（SwiftUI predictedEndTranslation）
    static func decide(dx: Double, dy: Double, predictedDX: Double, predictedDY: Double,
                       threshold: Double = SwipeLogic.threshold,
                       flickMinimum: Double = SwipeLogic.flickMinimum) -> SwipeOutcome {
        let horizontal = abs(dx) > abs(dy) * dominance
        let vertical = abs(dy) > abs(dx) * dominance
        if horizontal {
            // 快甩时预测落点也要是横向、同方向
            let flickOK = abs(dx) >= flickMinimum
                && abs(predictedDX) > abs(predictedDY) * dominance
                && abs(predictedDX) >= threshold
                && (predictedDX < 0) == (dx < 0)
            if abs(dx) >= threshold || flickOK {
                return dx < 0 ? .delete : .keep
            }
        } else if vertical && dy < 0 {
            let flickOK = -dy >= flickMinimum
                && abs(predictedDY) > abs(predictedDX) * dominance
                && -predictedDY >= threshold
            if -dy >= threshold || flickOK { return .later }
        }
        return .none
    }
}
