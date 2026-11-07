import SwiftUI
import AVFoundation
import Vision

// MARK: - 计数引擎

final class PoseCounter: NSObject, ObservableObject {

    @Published var reps = 0
    @Published var angle: Int = 0
    @Published var phase: String = "等待"
    @Published var status: String = "点开始，把手机横放在侧面"
    @Published var running = false

    let session = AVCaptureSession()

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "stride.pose.queue")
    private var configured = false
    private var wasDown = false

    // MARK: 控制

    func start() {
        guard !running else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            begin()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.begin() } else { self?.status = "相机权限被拒绝" }
                }
            }
        default:
            status = "相机权限被拒绝：设置 → 隐私 → 相机"
        }
    }

    func stop() {
        running = false
        if session.isRunning {
            queue.async { [weak self] in self?.session.stopRunning() }
        }
        status = "已暂停"
    }

    func reset() {
        reps = 0
        wasDown = false
        phase = "等待"
    }

    private func begin() {
        if !configured { configure() }
        guard configured else { return }
        running = true
        status = "识别中"
        queue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            status = "这台设备没有可用相机"
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .high

        if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
        configured = true
    }
}

extension PoseCounter: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard running else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            DispatchQueue.main.async { self.status = "分析失败：\(error.localizedDescription)" }
            return
        }

        guard let observation = request.results?.first else { return }
        guard let hip = try? observation.recognizedPoint(.rightHip),
              let knee = try? observation.recognizedPoint(.rightKnee),
              let ankle = try? observation.recognizedPoint(.rightAnkle),
              hip.confidence > 0.3, knee.confidence > 0.3, ankle.confidence > 0.3
        else {
            return
        }

        let value = Self.angle(hip.location, knee.location, ankle.location)
        DispatchQueue.main.async {
            self.angle = Int(value)
            if value < 105 {
                self.wasDown = true
                self.phase = "下蹲"
            } else if value > 155, self.wasDown {
                self.wasDown = false
                self.reps += 1
                self.phase = "站直"
            } else {
                self.phase = value > 155 ? "站直" : "过渡"
            }
        }
    }

    static func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let m1 = hypot(v1.dx, v1.dy)
        let m2 = hypot(v2.dx, v2.dy)
        guard m1 > 0.0001, m2 > 0.0001 else { return 0 }
        let cosine = max(-1, min(1, dot / (m1 * m2)))
        return acos(cosine) * 180 / Double.pi
    }
}

// MARK: - 预览

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = UIScreen.main.bounds
        view.layer.addSublayer(layer)
        context.coordinator.layer = layer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.layer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var layer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - 页面

struct RepCounterView: View {
    @StateObject private var counter = PoseCounter()

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            CameraPreview(session: counter.session)
                .ignoresSafeArea()
                .opacity(counter.running ? 1 : 0)

            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                VStack(spacing: 6) {
                    Text("\(counter.reps)")
                        .font(.system(size: 96, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("次")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                HStack(spacing: 10) {
                    infoBox("膝角", "\(counter.angle)°")
                    infoBox("状态", counter.phase)
                }
                .padding(.horizontal, Metrics.page)

                controls
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle("视觉计数")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onDisappear { counter.stop() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "viewfinder")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.green)
            Text(counter.status)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.45)))
        .padding(.horizontal, Metrics.page)
    }

    private func infoBox(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.1)))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                counter.running ? counter.stop() : counter.start()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: counter.running ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(counter.running ? "暂停" : "开始")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
            }
            .buttonStyle(.plain)

            Button {
                counter.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Metrics.page)
        .padding(.top, 12)
    }
}
