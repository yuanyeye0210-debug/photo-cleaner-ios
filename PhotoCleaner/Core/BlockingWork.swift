import Foundation

/// Vision、像素统计这类「同步、很重」的活放到专门的 GCD 线程上跑，
/// 不占 Swift 并发的协作线程池。协作线程池只有 CPU 核数那么多线程（模拟器 / 低端机可能只有 2~3 个），
/// 4 张照片同时在池子里同步跑 Vision 会把线程占满，PhotoKit 回调、Vision 内部的异步步骤都排不上，分析就卡住不动。
enum BlockingWork {
    private static let queue = DispatchQueue(label: "photocleaner.blocking-work", qos: .userInitiated, attributes: .concurrent)

    static func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { (cont: CheckedContinuation<T, Never>) in
            queue.async { cont.resume(returning: work()) }
        }
    }
}

/// 保证 continuation 只 resume 一次（PhotoKit 回调和超时谁先到用谁）
final class ResumeOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var cont: CheckedContinuation<T, Never>?
    init(_ cont: CheckedContinuation<T, Never>) { self.cont = cont }
    @discardableResult
    func resume(_ value: T) -> Bool {
        lock.lock()
        let c = cont; cont = nil
        lock.unlock()
        guard let c else { return false }
        c.resume(returning: value)
        return true
    }
}

/// 模拟器自检用的分析日志：只有设置了 PC_UITEST_TRACE_FILE 才写（正常使用完全不写）
enum ScanTrace {
    static let path: String? = ProcessInfo.processInfo.environment["PC_UITEST_TRACE_FILE"]
    private static let queue = DispatchQueue(label: "photocleaner.trace")
    private static let start = Date()

    static var enabled: Bool { path != nil }

    static func log(_ line: @autoclosure () -> String) {
        guard let path else { return }
        let text = String(format: "%7.2f ", Date().timeIntervalSince(start)) + line() + "\n"
        queue.async {
            let data = Data(text.utf8)
            if let h = FileHandle(forWritingAtPath: path) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                FileManager.default.createFile(atPath: path, contents: data)
            }
        }
    }
}
