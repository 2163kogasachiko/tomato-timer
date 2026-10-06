import SwiftUI
import AppKit
import AVFoundation

@MainActor
final class TimerModel: ObservableObject {
    enum Phase: String { case focus = "作業", shortBreak = "短い休憩", longBreak = "長い休憩" }
    enum SoundEvent { case breakStart, breakEnd }
    enum SoundChoice: String, CaseIterable, Identifiable {
        case chime, beeps, toyMarch, bell

        var id: String { rawValue }
        var title: String {
            switch self {
            case .chime: return "ド・ミ・ソ"
            case .beeps: return "ピピピピ"
            case .toyMarch: return "おもちゃ風マーチ（オリジナル）"
            case .bell: return "やさしいベル"
            }
        }
        var fileName: String {
            switch self {
            case .chime: return "timer-chime"
            case .beeps: return "timer-beeps"
            case .toyMarch: return "timer-toy-march"
            case .bell: return "timer-bell"
            }
        }
    }

    @Published var phase: Phase = .focus
    @Published var remaining = 25 * 60
    @Published var running = false
    @Published var completedFocus = 0
    @Published var focusMinutes = UserDefaults.standard.object(forKey: "focusMinutes") as? Int ?? 25
    @Published var shortBreakMinutes = UserDefaults.standard.object(forKey: "shortBreakMinutes") as? Int ?? 5
    @Published var longBreakMinutes = UserDefaults.standard.object(forKey: "longBreakMinutes") as? Int ?? 15
    @Published var breakStartSound = SoundChoice(rawValue: UserDefaults.standard.string(forKey: "breakStartSound") ?? "") ?? .chime
    @Published var breakEndSound = SoundChoice(rawValue: UserDefaults.standard.string(forKey: "breakEndSound") ?? "") ?? .chime
    @Published var showSettings = false
    var dragStart: NSPoint?

    private var deadline: Date?
    private var ticker: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var notificationPanel: NSPanel?
    private var notificationDismissal: Task<Void, Never>?

    var duration: Int {
        switch phase {
        case .focus: return focusMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }

    var clockText: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    var progress: Double { 1 - Double(remaining) / Double(duration) }

    init() {
        remaining = focusMinutes * 60
    }

    func toggle() {
        if running {
            let previousPhase = phase
            tick()
            guard phase == previousPhase else { return }
            ticker?.invalidate()
            ticker = nil
            deadline = nil
            running = false
        } else {
            start()
        }
    }

    private func start() {
        deadline = Date().addingTimeInterval(TimeInterval(remaining))
        running = true
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func playSound(_ choice: SoundChoice) {
        audioPlayer?.stop()
        guard let url = Bundle.main.url(forResource: choice.fileName, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            NSSound.beep()
            return
        }
        audioPlayer = player
        player.prepareToPlay()
        if !player.play() { NSSound.beep() }
    }

    func setSound(_ choice: SoundChoice, for event: SoundEvent) {
        switch event {
        case .breakStart:
            breakStartSound = choice
            UserDefaults.standard.set(choice.rawValue, forKey: "breakStartSound")
        case .breakEnd:
            breakEndSound = choice
            UserDefaults.standard.set(choice.rawValue, forKey: "breakEndSound")
        }
    }

    func reset() {
        ticker?.invalidate()
        ticker = nil
        deadline = nil
        running = false
        remaining = duration
    }

    func select(_ newPhase: Phase) {
        phase = newPhase
        reset()
    }

    func setMinutes(_ minutes: Int, for phase: Phase) {
        switch phase {
        case .focus:
            focusMinutes = minutes
            UserDefaults.standard.set(minutes, forKey: "focusMinutes")
        case .shortBreak:
            shortBreakMinutes = minutes
            UserDefaults.standard.set(minutes, forKey: "shortBreakMinutes")
        case .longBreak:
            longBreakMinutes = minutes
            UserDefaults.standard.set(minutes, forKey: "longBreakMinutes")
        }
        if self.phase == phase { reset() }
    }

    private func tick() {
        guard let deadline else { return }
        remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        if remaining == 0 { finish() }
    }

    private func finish() {
        ticker?.invalidate()
        ticker = nil
        deadline = nil
        running = false
        let finished = phase
        if finished == .focus {
            completedFocus += 1
            phase = completedFocus.isMultiple(of: 4) ? .longBreak : .shortBreak
        } else {
            phase = .focus
        }
        remaining = duration
        playSound(finished == .focus ? breakStartSound : breakEndSound)
        showNotification(
            title: finished == .focus ? "作業おつかれさま！" : "休憩終了！",
            message: finished == .focus ? "次は\(phase.rawValue)です。" : "作業を始めましょう。"
        )
        start()
    }

    private func showNotification(title: String, message: String) {
        notificationDismissal?.cancel()
        notificationPanel?.close()

        let size = NSSize(width: 350, height: 92)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isExcludedFromWindowsMenu = true

        let background = NSView(frame: NSRect(origin: .zero, size: size))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
        background.layer?.cornerRadius = 18
        background.layer?.masksToBounds = true

        let icon = NSImageView(frame: NSRect(x: 14, y: 15, width: 62, height: 62))
        icon.imageScaling = .scaleProportionallyUpOrDown
        if let path = Bundle.main.path(forResource: "tomato-cutout", ofType: "png") {
            icon.image = NSImage(contentsOfFile: path)
        }
        background.addSubview(icon)

        let heading = NSTextField(labelWithString: title)
        heading.frame = NSRect(x: 85, y: 49, width: 250, height: 26)
        heading.font = .boldSystemFont(ofSize: 16)
        heading.textColor = .labelColor
        background.addSubview(heading)

        let detail = NSTextField(labelWithString: message)
        detail.frame = NSRect(x: 85, y: 18, width: 250, height: 29)
        detail.font = .systemFont(ofSize: 14)
        detail.textColor = .secondaryLabelColor
        background.addSubview(detail)

        panel.contentView = background
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - size.width - 18,
                                         y: screen.visibleFrame.maxY - size.height - 18))
        }
        panel.orderFrontRegardless()
        notificationPanel = panel
        notificationDismissal = Task { [weak self, weak panel] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            panel?.close()
            self?.notificationPanel = nil
        }
    }
}

struct TomatoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()

        // 上中央の少しくぼんだ部分
        path.move(
            to: CGPoint(
                x: w * 0.50,
                y: h * 0.14
            )
        )

        // 左上
        path.addCurve(
            to: CGPoint(
                x: w * 0.18,
                y: h * 0.32
            ),
            control1: CGPoint(
                x: w * 0.42,
                y: h * 0.11
            ),
            control2: CGPoint(
                x: w * 0.24,
                y: h * 0.15
            )
        )

        // 左側〜左下
        path.addCurve(
            to: CGPoint(
                x: w * 0.28,
                y: h * 0.78
            ),
            control1: CGPoint(
                x: w * 0.07,
                y: h * 0.45
            ),
            control2: CGPoint(
                x: w * 0.12,
                y: h * 0.69
            )
        )

        // 下側
        path.addCurve(
            to: CGPoint(
                x: w * 0.72,
                y: h * 0.78
            ),
            control1: CGPoint(
                x: w * 0.38,
                y: h * 0.91
            ),
            control2: CGPoint(
                x: w * 0.62,
                y: h * 0.91
            )
        )

        // 右下〜右側
        path.addCurve(
            to: CGPoint(
                x: w * 0.82,
                y: h * 0.32
            ),
            control1: CGPoint(
                x: w * 0.88,
                y: h * 0.69
            ),
            control2: CGPoint(
                x: w * 0.93,
                y: h * 0.45
            )
        )

        // 右上〜くぼみへ戻る
        path.addCurve(
            to: CGPoint(
                x: w * 0.50,
                y: h * 0.14
            ),
            control1: CGPoint(
                x: w * 0.76,
                y: h * 0.15
            ),
            control2: CGPoint(
                x: w * 0.58,
                y: h * 0.11
            )
        )

        path.closeSubpath()

        return path
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        let x = rect.width / 2, y = rect.height * 0.55
        var p = Path()
        for i in 0..<5 {
            let angle = Double(i) * .pi * 2 / 5 - .pi / 2
            let left = angle - 0.36, right = angle + 0.36
            p.move(to: CGPoint(x: x, y: y))
            p.addQuadCurve(to: CGPoint(x: x + cos(angle) * rect.width * 0.42, y: y + sin(angle) * rect.height * 0.47), control: CGPoint(x: x + cos(left) * rect.width * 0.25, y: y + sin(left) * rect.height * 0.26))
            p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + cos(right) * rect.width * 0.25, y: y + sin(right) * rect.height * 0.26))
        }
        return p
    }
}

struct ContentView: View {
    @StateObject private var timer = TimerModel()
    private let cream = Color(red: 1, green: 0.96, blue: 0.86)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 420, geometry.size.height / 430)
            timerFace
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minWidth: 300, minHeight: 310)
    }

    private var timerFace: some View {
        ZStack {
            if let path = Bundle.main.path(forResource: "tomato-cutout", ofType: "png"),
               let photo = NSImage(contentsOfFile: path) {
                Image(nsImage: photo)
                    .resizable()
                    .frame(width: 400, height: 400)
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 7)
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                guard let window = mainWindow() else { return }
                                if timer.dragStart == nil { timer.dragStart = window.frame.origin }
                                guard let start = timer.dragStart else { return }
                                window.setFrameOrigin(NSPoint(x: start.x + value.translation.width,
                                                              y: start.y - value.translation.height))
                            }
                            .onEnded { _ in timer.dragStart = nil }
                    )
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 124)

                Text(timer.phase.rawValue)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .shadow(color: .black.opacity(0.55), radius: 3, y: 1)

                Text(timer.clockText)
                    .font(.system(size: 68, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .padding(.top, 1)
                    .shadow(color: .black.opacity(0.55), radius: 3, y: 1)

                ProgressView(value: timer.progress)
                    .tint(cream)
                    .frame(width: 205)
                    .padding(.top, 7)

                HStack(spacing: 14) {
                    Button(timer.running ? "一時停止" : "開始") { timer.toggle() }
                        .buttonStyle(TomatoButton(primary: true))
                    Button("リセット") { timer.reset() }
                        .buttonStyle(TomatoButton(primary: false))
                }
                .padding(.top, 17)

                HStack(spacing: 13) {
                    phaseButton("作業", .focus)
                    phaseButton("短い休憩", .shortBreak)
                    phaseButton("長い休憩", .longBreak)
                }
                .padding(.top, 14)

                Text("完了した作業  \(timer.completedFocus) / 4")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .opacity(0.85)
                    .padding(.top, 8)
                    .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(cream)
            .frame(width: 330, height: 400)

            Button { timer.showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(cream)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.28)))
            }
            .buttonStyle(.plain)
            .offset(x: 120, y: -74)
        }
        .frame(width: 420, height: 430)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.42, green: 0.08, blue: 0.06))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color(red: 1, green: 0.38, blue: 0.35)))
                }
                .accessibilityLabel("アプリを終了")

                Button { mainWindow()?.miniaturize(nil) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.48, green: 0.32, blue: 0.04))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color(red: 1, green: 0.78, blue: 0.28)))
                }
                .accessibilityLabel("ウィンドウをDockにしまう")
            }
            .buttonStyle(.plain)
            .padding(.leading, 21)
            .padding(.top, 32)
        }
        .background(WindowConfigurator())
        .sheet(isPresented: $timer.showSettings) {
            VStack(alignment: .leading, spacing: 18) {
                Text("タイマーの設定").font(.title2.bold())
                durationStepper("作業", .focus, range: 1...180)
                durationStepper("短い休憩", .shortBreak, range: 1...60)
                durationStepper("長い休憩", .longBreak, range: 1...60)
                Divider()
                soundPicker("休憩開始の音", .breakStart)
                soundPicker("休憩終了の音", .breakEnd)
                Text("変更中のタイマーはリセットされます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("バージョン 2.9")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("完了") { timer.showSettings = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 380)
        }
    }

    private func mainWindow() -> NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == "TomatoTimerMainWindow" } ?? NSApp.keyWindow
    }

    private func phaseButton(_ title: String, _ phase: TimerModel.Phase) -> some View {
        Button(title) { timer.select(phase) }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: timer.phase == phase ? .bold : .medium, design: .rounded))
            .opacity(timer.phase == phase ? 1 : 0.65)
            .padding(.bottom, 4)
            .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
            .overlay(alignment: .bottom) {
                if timer.phase == phase { Capsule().fill(cream).frame(height: 2) }
            }
    }

    private func durationStepper(_ title: String, _ phase: TimerModel.Phase, range: ClosedRange<Int>) -> some View {
        let minutes = Binding<Int>(
            get: {
                switch phase {
                case .focus: return timer.focusMinutes
                case .shortBreak: return timer.shortBreakMinutes
                case .longBreak: return timer.longBreakMinutes
                }
            },
            set: { timer.setMinutes($0, for: phase) }
        )
        return Stepper(value: minutes, in: range) {
            HStack {
                Text(title)
                Spacer()
                Text("\(minutes.wrappedValue)分").monospacedDigit()
            }
        }
    }

    private func soundPicker(_ title: String, _ event: TimerModel.SoundEvent) -> some View {
        let selection = Binding<TimerModel.SoundChoice>(
            get: { event == .breakStart ? timer.breakStartSound : timer.breakEndSound },
            set: { timer.setSound($0, for: event) }
        )
        return HStack {
            Picker(title, selection: selection) {
                ForEach(TimerModel.SoundChoice.allCases) { sound in
                    Text(sound.title).tag(sound)
                }
            }
            .pickerStyle(.menu)
            Button("試聴") { timer.playSound(selection.wrappedValue) }
        }
    }
}

struct TomatoButton: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(primary ? Color(red: 0.72, green: 0.12, blue: 0.10) : Color.white)
            .frame(width: 112, height: 39)
            .background(Capsule().fill(primary ? Color(red: 1, green: 0.96, blue: 0.86) : Color.white.opacity(0.18)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(primary ? 0 : 0.5)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(view.window) }
    }
    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.identifier = NSUserInterfaceItemIdentifier("TomatoTimerMainWindow")
        window.styleMask.insert(.miniaturizable)
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 300, height: 310)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    }
}

final class TomatoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let path = Bundle.main.path(forResource: "tomato-cutout", ofType: "png"),
           let icon = NSImage(contentsOfFile: path) {
            NSApp.applicationIconImage = icon
        }
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowClosed(_:)),
                                               name: NSWindow.willCloseNotification, object: nil)
    }

    @objc private func mainWindowClosed(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.identifier?.rawValue == "TomatoTimerMainWindow" else { return }
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct TomatoTimerApp: App {
    @NSApplicationDelegateAdaptor(TomatoAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 430)
    }
}
