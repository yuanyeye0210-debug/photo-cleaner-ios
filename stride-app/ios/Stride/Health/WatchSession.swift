import Foundation
import Combine
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// 手机侧的 Watch 桥接：把正在进行的训练和休息计时推给手表。
/// 手表端需要单独一个 watchOS target，`WatchApp/` 里有可直接拖进 Xcode 的骨架说明。
@MainActor
final class WatchSession: NSObject, ObservableObject {
    static let shared = WatchSession()

    @Published var supported = false
    @Published var reachable = false
    @Published var pairedName: String?
    @Published var lastEvent: String?
    @Published var lastEventAt: Date?

    #if canImport(WatchConnectivity)
    private var session: WCSession { WCSession.default }
    #endif

    func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else {
            supported = false
            return
        }
        supported = true
        session.delegate = self
        session.activate()
        #else
        supported = false
        #endif
    }

    /// 推一条训练状态给手表
    func push(workoutTitle: String, elapsed: Int, setIndex: Int, totalSets: Int) {
        #if canImport(WatchConnectivity)
        guard supported, session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "kind": "workout",
            "title": workoutTitle,
            "elapsed": elapsed,
            "setIndex": setIndex,
            "totalSets": totalSets,
            "at": Date().timeIntervalSince1970
        ]
        send(payload)
        #endif
    }

    /// 休息开始 / 结束
    func push(restSeconds: Int, running: Bool) {
        #if canImport(WatchConnectivity)
        guard supported, session.activationState == .activated else { return }
        send(["kind": running ? "restStart" : "restEnd", "seconds": restSeconds])
        #endif
    }

    #if canImport(WatchConnectivity)
    private func send(_ payload: [String: Any]) {
        // 手表不在腕上时用 applicationContext 保底，保证下一次唤醒能拿到最新状态
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastEvent = "发送失败：\(error.localizedDescription)"
                    self?.lastEventAt = Date()
                }
            }
        } else {
            try? session.updateApplicationContext(payload)
        }
        lastEventAt = Date()
    }
    #endif
}

#if canImport(WatchConnectivity)
extension WatchSession: WCSessionDelegate {

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        let paired = session.isPaired && session.isWatchAppInstalled
        Task { @MainActor in
            self.reachable = reachable
            self.pairedName = paired ? "已配对" : nil
            self.lastEvent = activationState == .activated ? "已连接" : "未激活"
            self.lastEventAt = Date()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.reachable = reachable
            self.lastEvent = reachable ? "手表在线" : "手表离线"
            self.lastEventAt = Date()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let text = message["kind"] as? String ?? "unknown"
        Task { @MainActor in
            self.lastEvent = "手表：\(text)"
            self.lastEventAt = Date()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in self.reachable = false }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
        Task { @MainActor in
            self.reachable = false
            self.lastEvent = "会话重建中"
            self.lastEventAt = Date()
        }
    }
}
#endif
