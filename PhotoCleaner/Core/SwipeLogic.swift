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

/// 卡片里图片的摆放：普通照片铺满；截图、长图、全景等比例差很多的，整张缩小放在卡片上半部分
enum SwipeCardLayout {
    static let inset: CGFloat = 14
    /// 给底部标签 / 日期留的高度
    static let infoHeight: CGFloat = 96

    /// 需要整张显示时返回图片的显示尺寸，铺满时返回 nil
    static func fittedSize(imageWidth: Int, imageHeight: Int, isScreenshot: Bool, card: CGSize) -> CGSize? {
        guard imageWidth > 0, imageHeight > 0, card.width > 1, card.height > 1 else { return nil }
        let img = CGFloat(imageWidth) / CGFloat(imageHeight)
        let box = card.width / card.height
        let mismatch = max(img / box, box / img)
        // 手机屏幕形状的竖长图（19.5:9 等）基本都是截图，即使系统没标成截图（比如别的 App 存下来的）
        let phoneShaped = CGFloat(imageHeight) / CGFloat(imageWidth) >= 2.0
        guard isScreenshot || phoneShaped || mismatch > 2.0 else { return nil }
        let availW = card.width - inset * 2
        let availH = card.height - inset - infoHeight
        guard availW > 20, availH > 20 else { return nil }
        if img > availW / availH {
            return CGSize(width: availW.rounded(), height: (availW / img).rounded())
        } else {
            return CGSize(width: (availH * img).rounded(), height: availH.rounded())
        }
    }
}
