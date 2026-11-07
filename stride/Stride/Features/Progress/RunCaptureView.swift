import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - 记录器

final class RunTracker: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published private(set) var points: [GeoPoint] = []
    @Published private(set) var distanceM: Double = 0
    @Published private(set) var seconds: Int = 0
    @Published private(set) var running = false
    @Published var status: String = "待开始"
    @Published var authorized: Bool = false
    @Published var isDemo: Bool = false

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 3
    }

    deinit {
        timer?.invalidate()
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        guard !running else { return }
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        points = []
        distanceM = 0
        seconds = 0
        lastLocation = nil
        isDemo = false
        running = true
        status = "记录中"
        manager.startUpdatingLocation()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.running else { return }
            self.seconds += 1
        }
    }

    func stop() {
        running = false
        manager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        status = "已结束"
    }

    func reset() {
        stop()
        points = []
        distanceM = 0
        seconds = 0
        status = "待开始"
    }

    /// 模拟器/室内预览用：不做 GPS 也能量出一段轨迹
    func loadDemo(km: Double = 5.2) {
        stop()
        isDemo = true
        points = SeedData.loop(center: (31.2304, 121.4737), radius: 0.006, count: 260, seed: 7)
        distanceM = km * 1000
        seconds = Int(km * 330)
        status = "模拟轨迹"
    }

    var pace: Int {
        guard distanceM > 50 else { return 0 }
        return Int(Double(seconds) / (distanceM / 1000))
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorized = true
            status = running ? "记录中" : "已授权"
        case .denied, .restricted:
            authorized = false
            status = "定位被拒绝：设置 → 隐私 → 定位服务"
        default:
            authorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard running, let location = locations.last, location.horizontalAccuracy < 40 else { return }
        if let last = lastLocation {
            let delta = location.distance(from: last)
            if delta > 0.8 { distanceM += delta }
        }
        lastLocation = location
        points.append(GeoPoint(lat: location.coordinate.latitude, lon: location.coordinate.longitude))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        status = "定位失败：\(error.localizedDescription)"
    }
}

// MARK: - 记录页

struct RunCaptureView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var tracker = RunTracker()
    @State private var camera: MapCameraPosition = .automatic
    @State private var title = "夜跑"
    @State private var showMembership = false
    @State private var toast: String?

    private var coords: [CLLocationCoordinate2D] {
        tracker.points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    mapArea
                    statsPanel
                    controls
                }
            }
            .navigationTitle("记一次跑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { tracker.reset(); dismiss() }
                        .foregroundStyle(Palette.textDim)
                }
            }
            .onAppear { tracker.requestPermission() }
            .membershipSheet($showMembership)
            .toast($toast)
        }
    }

    private var mapArea: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $camera) {
                if coords.count > 1 {
                    MapPolyline(coordinates: coords)
                        .stroke(Palette.green, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
            .padding(.horizontal, Metrics.page)
            .padding(.top, 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(tracker.running ? Palette.green : Palette.textFaint)
                    .frame(width: 6, height: 6)
                Text(tracker.status)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.text)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(Palette.card.opacity(0.9)))
            .padding(.leading, Metrics.page + 12)
            .padding(.top, 20)
        }
    }

    private var statsPanel: some View {
        HStack(spacing: 0) {
            stat(String(format: "%.2f", tracker.distanceM / 1000), "公里", Palette.green)
            divider
            stat(paceText, "配速", Palette.text)
            divider
            stat(timeText, "时长", Palette.text)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
        .padding(.horizontal, Metrics.page)
        .padding(.top, 14)
    }

    private var divider: some View {
        Rectangle().fill(Palette.stroke).frame(width: 0.5, height: 30)
    }

    private func stat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private var paceText: String {
        guard tracker.pace > 0 else { return "—" }
        return String(format: "%d′%02d″", tracker.pace / 60, tracker.pace % 60)
    }

    private var timeText: String {
        String(format: "%d:%02d", tracker.seconds / 60, tracker.seconds % 60)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            TextField("给这次跑步起个名", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))

            HStack(spacing: 10) {
                Button {
                    if tracker.running {
                        tracker.stop()
                    } else {
                        tracker.start()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tracker.running ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(tracker.running ? "暂停" : "开始")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                }
                .buttonStyle(.plain)

                Button {
                    tracker.loadDemo()
                    toast = "已载入模拟轨迹"
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 50, height: 50)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.cardHigh))
                }
                .buttonStyle(.plain)

                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 50, height: 50)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.green))
                }
                .buttonStyle(.plain)
                .disabled(tracker.points.isEmpty)
                .opacity(tracker.points.isEmpty ? 0.4 : 1)
            }
        }
        .padding(.horizontal, Metrics.page)
        .padding(.top, 12)
    }

    private func save() {
        tracker.stop()
        let run = RouteRun(
            date: Date(),
            title: title.isEmpty ? "跑步" : title,
            distanceM: tracker.distanceM,
            durationSec: max(tracker.seconds, 60),
            points: tracker.points,
            styleRaw: RouteArtStyle.neon.rawValue
        )
        store.addRun(run)
        dismiss()
    }
}
