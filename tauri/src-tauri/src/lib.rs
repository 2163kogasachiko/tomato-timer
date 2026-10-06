use serde::{Deserialize, Serialize};
use std::io::{BufReader, Cursor};
use std::sync::mpsc::{Receiver, Sender};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Emitter, Manager, State, WebviewUrl, WebviewWindowBuilder};

// ---------- モデル ----------

#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
enum Phase {
    Focus,
    ShortBreak,
    LongBreak,
}

impl Phase {
    fn label(self) -> &'static str {
        match self {
            Phase::Focus => "作業",
            Phase::ShortBreak => "短い休憩",
            Phase::LongBreak => "長い休憩",
        }
    }
    fn range(self) -> (u32, u32) {
        match self {
            Phase::Focus => (1, 180),
            _ => (1, 60),
        }
    }
}

#[derive(Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
enum SoundChoice {
    Chime,
    Beeps,
    ToyMarch,
    Bell,
}

impl SoundChoice {
    fn bytes(self) -> &'static [u8] {
        match self {
            SoundChoice::Chime => include_bytes!("../assets/timer-chime.wav"),
            SoundChoice::Beeps => include_bytes!("../assets/timer-beeps.wav"),
            SoundChoice::ToyMarch => include_bytes!("../assets/timer-toy-march.wav"),
            SoundChoice::Bell => include_bytes!("../assets/timer-bell.wav"),
        }
    }
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct NotificationPayload {
    title: &'static str,
    message: String,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct Snapshot {
    phase: Phase,
    phase_label: &'static str,
    remaining: i64,
    running: bool,
    completed_focus: u32,
    duration: i64,
    progress: f64,
    focus_minutes: u32,
    short_break_minutes: u32,
    long_break_minutes: u32,
    focus_start_sound: SoundChoice,
    break_start_sound: SoundChoice,
    break_end_sound: SoundChoice,
}

struct Timer {
    phase: Phase,
    remaining_secs: i64,
    running: bool,
    completed_focus: u32,
    deadline_ms: i64,
    paused_ms: Option<i64>,
    focus_minutes: u32,
    short_break_minutes: u32,
    long_break_minutes: u32,
    focus_start_sound: SoundChoice,
    break_start_sound: SoundChoice,
    break_end_sound: SoundChoice,
    notification_seq: u64,
    last_notification: Option<NotificationPayload>,
}

impl Timer {
    fn new() -> Self {
        Self {
            phase: Phase::Focus,
            remaining_secs: 25 * 60,
            running: false,
            completed_focus: 0,
            deadline_ms: 0,
            paused_ms: None,
            focus_minutes: 25,
            short_break_minutes: 5,
            long_break_minutes: 15,
            focus_start_sound: SoundChoice::Chime,
            break_start_sound: SoundChoice::Chime,
            break_end_sound: SoundChoice::Chime,
            notification_seq: 0,
            last_notification: None,
        }
    }

    fn minutes(&self, phase: Phase) -> u32 {
        match phase {
            Phase::Focus => self.focus_minutes,
            Phase::ShortBreak => self.short_break_minutes,
            Phase::LongBreak => self.long_break_minutes,
        }
    }

    fn duration_secs(&self) -> i64 {
        self.minutes(self.phase) as i64 * 60
    }

    fn snapshot(&self) -> Snapshot {
        Snapshot {
            phase: self.phase,
            phase_label: self.phase.label(),
            remaining: self.remaining_secs,
            running: self.running,
            completed_focus: self.completed_focus,
            duration: self.duration_secs(),
            progress: 1.0 - self.remaining_secs as f64 / self.duration_secs() as f64,
            focus_minutes: self.focus_minutes,
            short_break_minutes: self.short_break_minutes,
            long_break_minutes: self.long_break_minutes,
            focus_start_sound: self.focus_start_sound,
            break_start_sound: self.break_start_sound,
            break_end_sound: self.break_end_sound,
        }
    }

    fn reset(&mut self) {
        self.running = false;
        self.deadline_ms = 0;
        self.paused_ms = None;
        self.remaining_secs = self.duration_secs();
    }

    /// フェーズ終了時の処理。通知内容を返す。
    fn finish(&mut self, now: i64) -> NotificationPayload {
        self.running = false;
        self.deadline_ms = 0;
        self.paused_ms = None;
        let finished = self.phase;
        if finished == Phase::Focus {
            self.completed_focus += 1;
            self.phase = if self.completed_focus % 4 == 0 {
                Phase::LongBreak
            } else {
                Phase::ShortBreak
            };
        } else {
            self.phase = Phase::Focus;
            if finished == Phase::LongBreak {
                self.completed_focus %= 4;
            }
        }
        self.remaining_secs = self.duration_secs();
        let payload = NotificationPayload {
            title: if finished == Phase::Focus {
                "作業おつかれさま！"
            } else {
                "休憩終了！"
            },
            message: if finished == Phase::Focus {
                format!("次は{}です。", self.phase.label())
            } else {
                "作業を始めましょう。".to_string()
            },
        };
        // 自動で次のフェーズを開始
        self.deadline_ms = now + self.duration_secs() * 1000;
        self.running = true;
        payload
    }
}

fn epoch_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

// ---------- 音声 ----------
// rodio の型は Send/Sync ではないため、音声専用スレッドがストリームを持ち、
// 再生要求はチャネルで送る。

fn audio_thread(rx: Receiver<SoundChoice>) {
    let Ok(stream) = rodio::OutputStreamBuilder::open_default_stream() else {
        // 音声出力が使えない環境でもチャネルだけは読み続ける
        while rx.recv().is_ok() {}
        return;
    };
    let mut current: Option<rodio::Sink> = None;
    for choice in rx {
        if let Some(sink) = current.take() {
            sink.stop();
        }
        match rodio::Decoder::new(BufReader::new(Cursor::new(choice.bytes()))) {
            Ok(src) => {
                let sink = rodio::Sink::connect_new(stream.mixer());
                sink.append(src);
                current = Some(sink);
            }
            Err(_) => {
                // 再生失敗時はビープ音にフォールバック
                use rodio::Source;
                let sink = rodio::Sink::connect_new(stream.mixer());
                sink.append(
                    rodio::source::SineWave::new(880.0)
                        .take_duration(Duration::from_millis(400))
                        .amplify(0.2),
                );
                sink.detach();
            }
        }
    }
}

// ---------- アプリ状態 ----------

struct AppState {
    timer: Mutex<Timer>,
    sound_tx: Sender<SoundChoice>,
}

impl AppState {
    fn play(&self, choice: SoundChoice) {
        let _ = self.sound_tx.send(choice);
    }
}

fn emit_state(app: &AppHandle, timer: &Timer) {
    let _ = app.emit("timer-state", timer.snapshot());
}

fn persist_settings(app: &AppHandle, timer: &Timer) {
    #[derive(Serialize)]
    #[serde(rename_all = "camelCase")]
    struct Persisted {
        focus_minutes: u32,
        short_break_minutes: u32,
        long_break_minutes: u32,
        focus_start_sound: SoundChoice,
        break_start_sound: SoundChoice,
        break_end_sound: SoundChoice,
    }
    let persisted = Persisted {
        focus_minutes: timer.focus_minutes,
        short_break_minutes: timer.short_break_minutes,
        long_break_minutes: timer.long_break_minutes,
        focus_start_sound: timer.focus_start_sound,
        break_start_sound: timer.break_start_sound,
        break_end_sound: timer.break_end_sound,
    };
    if let Ok(dir) = app.path().app_config_dir() {
        let _ = std::fs::create_dir_all(&dir);
        if let Ok(json) = serde_json::to_string_pretty(&persisted) {
            let _ = std::fs::write(dir.join("settings.json"), json);
        }
    }
}

fn load_settings(app: &AppHandle, timer: &mut Timer) {
    #[derive(Deserialize)]
    #[serde(rename_all = "camelCase", default)]
    struct Persisted {
        focus_minutes: u32,
        short_break_minutes: u32,
        long_break_minutes: u32,
        focus_start_sound: SoundChoice,
        break_start_sound: SoundChoice,
        break_end_sound: SoundChoice,
    }
    impl Default for Persisted {
        fn default() -> Self {
            Self {
                focus_minutes: 25,
                short_break_minutes: 5,
                long_break_minutes: 15,
                focus_start_sound: SoundChoice::Chime,
                break_start_sound: SoundChoice::Chime,
                break_end_sound: SoundChoice::Chime,
            }
        }
    }
    let Ok(path) = app.path().app_config_dir().map(|d| d.join("settings.json")) else {
        return;
    };
    let Ok(file) = std::fs::File::open(path) else {
        return;
    };
    let Ok(p) = serde_json::from_reader::<_, Persisted>(file) else {
        return;
    };
    timer.focus_minutes = p.focus_minutes.clamp(1, 180);
    timer.short_break_minutes = p.short_break_minutes.clamp(1, 60);
    timer.long_break_minutes = p.long_break_minutes.clamp(1, 60);
    timer.focus_start_sound = p.focus_start_sound;
    timer.break_start_sound = p.break_start_sound;
    timer.break_end_sound = p.break_end_sound;
    timer.remaining_secs = timer.duration_secs();
}

// ---------- 通知ウィンドウ ----------

#[cfg(target_os = "macos")]
fn configure_notification_window(window: &tauri::WebviewWindow) {
    use objc::runtime::Object;
    use objc::{msg_send, sel, sel_impl};
    unsafe {
        let ns_window = window.ns_window().unwrap() as *mut Object;
        // NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary
        let _: () = msg_send![ns_window, setCollectionBehavior: 1usize | (1usize << 8)];
        // NSFloatingWindowLevel
        let _: () = msg_send![ns_window, setLevel: 3i64];
        let _: () = msg_send![ns_window, orderFrontRegardless];
    }
}

fn show_notification(app: &AppHandle) {
    // 既存の通知があれば閉じる
    if let Some(existing) = app.get_webview_window("notification") {
        let _ = existing.close();
    }

    let Ok(window) = WebviewWindowBuilder::new(
        app,
        "notification",
        WebviewUrl::App("notification.html".into()),
    )
    .title("")
    .inner_size(350.0, 92.0)
    .decorations(false)
    .transparent(true)
    .resizable(false)
    .always_on_top(true)
    .skip_taskbar(true)
    .focused(false)
    .visible(false)
    .build()
    else {
        return;
    };

    // プライマリディスプレイの右上に配置
    if let Ok(Some(monitor)) = window.primary_monitor() {
        let scale = monitor.scale_factor();
        let pos = monitor.position();
        let size = monitor.size();
        let x = pos.x + size.width as i32 - ((350.0 + 18.0) * scale) as i32;
        let y = pos.y + (18.0 * scale) as i32;
        let _ = window.set_position(tauri::PhysicalPosition::new(x, y));
    }

    let _ = window.show();

    #[cfg(target_os = "macos")]
    configure_notification_window(&window);

    // 6秒後に自動で閉じる（その間に新しい通知が出ていれば閉じない）
    let state = app.state::<AppState>();
    let seq = {
        let mut timer = state.timer.lock().unwrap();
        timer.notification_seq += 1;
        timer.notification_seq
    };
    let app_handle = app.clone();
    std::thread::spawn(move || {
        std::thread::sleep(Duration::from_secs(6));
        let state = app_handle.state::<AppState>();
        let current = state.timer.lock().unwrap().notification_seq;
        if current == seq {
            if let Some(w) = app_handle.get_webview_window("notification") {
                let _ = w.close();
            }
        }
    });
}

// ---------- コマンド ----------

#[tauri::command]
fn get_state(state: State<AppState>) -> Snapshot {
    state.timer.lock().unwrap().snapshot()
}

#[tauri::command]
fn toggle(app: AppHandle, state: State<AppState>) -> Snapshot {
    let mut timer = state.timer.lock().unwrap();
    let now = epoch_ms();
    let mut sound: Option<SoundChoice> = None;
    let mut notify = false;

    if timer.running {
        if now >= timer.deadline_ms {
            // ちょうど終了時刻を跨いでいたらフェーズ完了処理を先に行う
            let finished = timer.phase;
            let payload = timer.finish(now);
            sound = Some(if finished == Phase::Focus {
                timer.break_start_sound
            } else {
                timer.break_end_sound
            });
            timer.last_notification = Some(payload);
            notify = true;
        } else {
            // 秒未満の端数を保持して一時停止
            timer.paused_ms = Some(timer.deadline_ms - now);
            timer.remaining_secs = (timer.deadline_ms - now + 999) / 1000;
            timer.deadline_ms = 0;
            timer.running = false;
        }
    } else {
        // 開始・再開時はフェーズに応じた音を鳴らす
        sound = Some(if timer.phase == Phase::Focus {
            timer.focus_start_sound
        } else {
            timer.break_start_sound
        });
        timer.deadline_ms = now + timer.paused_ms.take().unwrap_or(timer.remaining_secs * 1000);
        timer.running = true;
    }

    emit_state(&app, &timer);
    let snapshot = timer.snapshot();
    drop(timer);

    if notify {
        show_notification(&app);
    }
    if let Some(s) = sound {
        state.play(s);
    }
    snapshot
}

#[tauri::command]
fn reset(app: AppHandle, state: State<AppState>) -> Snapshot {
    let mut timer = state.timer.lock().unwrap();
    timer.reset();
    let snapshot = timer.snapshot();
    emit_state(&app, &timer);
    snapshot
}

#[tauri::command]
fn select_phase(app: AppHandle, state: State<AppState>, phase: Phase) -> Snapshot {
    let mut timer = state.timer.lock().unwrap();
    timer.phase = phase;
    timer.reset();
    let snapshot = timer.snapshot();
    emit_state(&app, &timer);
    snapshot
}

#[tauri::command]
fn set_minutes(app: AppHandle, state: State<AppState>, phase: Phase, minutes: u32) -> Snapshot {
    let mut timer = state.timer.lock().unwrap();
    let (lo, hi) = phase.range();
    let minutes = minutes.clamp(lo, hi);
    match phase {
        Phase::Focus => timer.focus_minutes = minutes,
        Phase::ShortBreak => timer.short_break_minutes = minutes,
        Phase::LongBreak => timer.long_break_minutes = minutes,
    }
    if timer.phase == phase {
        timer.reset();
    }
    persist_settings(&app, &timer);
    let snapshot = timer.snapshot();
    emit_state(&app, &timer);
    snapshot
}

#[tauri::command]
fn set_sound(
    app: AppHandle,
    state: State<AppState>,
    event: String,
    sound: SoundChoice,
) -> Snapshot {
    let mut timer = state.timer.lock().unwrap();
    match event.as_str() {
        "focusStart" => timer.focus_start_sound = sound,
        "breakStart" => timer.break_start_sound = sound,
        "breakEnd" => timer.break_end_sound = sound,
        _ => {}
    }
    persist_settings(&app, &timer);
    let snapshot = timer.snapshot();
    emit_state(&app, &timer);
    snapshot
}

#[tauri::command]
fn preview_sound(state: State<AppState>, sound: SoundChoice) {
    state.play(sound);
}

#[tauri::command]
fn get_notification(state: State<AppState>) -> Option<NotificationPayload> {
    state.timer.lock().unwrap().last_notification.clone()
}

// ---------- 起動 ----------

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage({
            let (sound_tx, sound_rx) = std::sync::mpsc::channel::<SoundChoice>();
            std::thread::spawn(move || audio_thread(sound_rx));
            AppState {
                timer: Mutex::new(Timer::new()),
                sound_tx,
            }
        })
        .invoke_handler(tauri::generate_handler![
            get_state,
            toggle,
            reset,
            select_phase,
            set_minutes,
            set_sound,
            preview_sound,
            get_notification,
        ])
        .setup(|app| {
            // 保存済み設定を読み込む
            {
                let state = app.state::<AppState>();
                let mut timer = state.timer.lock().unwrap();
                load_settings(&app.handle().clone(), &mut timer);
            }

            // 0.25秒ごとのティック。期限基準で計算するのでスリープしても残り時間はずれない
            let app_handle = app.handle().clone();
            std::thread::spawn(move || loop {
                std::thread::sleep(Duration::from_millis(250));
                let now = epoch_ms();
                let state = app_handle.state::<AppState>();
                let mut timer = state.timer.lock().unwrap();
                if !timer.running {
                    continue;
                }
                if now >= timer.deadline_ms {
                    let finished = timer.phase;
                    let payload = timer.finish(now);
                    let sound = if finished == Phase::Focus {
                        timer.break_start_sound
                    } else {
                        timer.break_end_sound
                    };
                    timer.last_notification = Some(payload);
                    emit_state(&app_handle, &timer);
                    drop(timer);
                    show_notification(&app_handle);
                    let state = app_handle.state::<AppState>();
                    state.play(sound);
                } else {
                    let secs = (timer.deadline_ms - now + 999) / 1000;
                    if secs != timer.remaining_secs {
                        timer.remaining_secs = secs;
                        emit_state(&app_handle, &timer);
                    }
                }
            });
            Ok(())
        })
        .on_window_event(|window, event| {
            // メインウィンドウを閉じるとアプリも終了する
            if let tauri::WindowEvent::Destroyed = event {
                if window.label() == "main" {
                    window.app_handle().exit(0);
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
