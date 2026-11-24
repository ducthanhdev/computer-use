use std::process::Command;
use tracing::info;

pub struct SystemController;

impl SystemController {
    pub fn handle_action(action: &str) -> (bool, String) {
        match action {
            "vol_up" => Self::volume_change(5),
            "vol_down" => Self::volume_change(-5),
            "vol_mute" => Self::volume_mute(),
            "media_play_pause" => Self::media_control("play-pause"),
            "media_next" => Self::media_control("next"),
            "media_prev" => Self::media_control("previous"),
            "lock_screen" => Self::lock_session(),
            "suspend" => Self::suspend_system(),
            "ping_notify" => Self::send_notification("DeskPulse Mobile", "Kết nối Flutter App thành công!"),
            unknown => (false, format!("Unknown action: {unknown}")),
        }
    }

    pub fn handle_mouse_move(dx: i32, dy: i32) -> (bool, String) {
        // Use xdotool if present for low-latency X11 pointer emulation
        if Self::command_exists("xdotool") {
            let res = Command::new("xdotool")
                .args(["mousemove_relative", "--", &dx.to_string(), &dy.to_string()])
                .output();
            match res {
                Ok(_) => (true, "Mouse moved".into()),
                Err(e) => (false, format!("Failed to move mouse: {e}")),
            }
        } else {
            (false, "xdotool is not installed for mouse emulation".into())
        }
    }

    pub fn handle_mouse_click(button: &str) -> (bool, String) {
        let btn_num = match button {
            "right" => "3",
            "middle" => "2",
            _ => "1", // default left
        };

        if Self::command_exists("xdotool") {
            let _ = Command::new("xdotool").args(["click", btn_num]).output();
            (true, format!("Clicked {button}"))
        } else {
            (false, "xdotool not installed".into())
        }
    }

    pub fn handle_mouse_scroll(dy: i32) -> (bool, String) {
        if Self::command_exists("xdotool") {
            // Button 4 is scroll up, 5 is scroll down
            let btn = if dy > 0 { "4" } else { "5" };
            let count = dy.abs().clamp(1, 10);
            for _ in 0..count {
                let _ = Command::new("xdotool").args(["click", btn]).output();
            }
            (true, "Scrolled".into())
        } else {
            (false, "xdotool not installed".into())
        }
    }

    fn volume_change(delta: i32) -> (bool, String) {
        let sign = if delta > 0 { format!("{delta}%+") } else { format!("{}%-", delta.abs()) };

        if Self::command_exists("wpctl") {
            if let Ok(out) = Command::new("wpctl").args(["set-volume", "@DEFAULT_AUDIO_SINK@", &sign]).output() {
                if out.status.success() {
                    return (true, format!("Volume changed by {delta}%"));
                }
            }
        }

        if Self::command_exists("pactl") {
            let p_sign = if delta > 0 { format!("+{delta}%") } else { format!("-{delta}%") };
            if let Ok(out) = Command::new("pactl").args(["set-sink-volume", "@DEFAULT_SINK@", &p_sign]).output() {
                if out.status.success() {
                    return (true, format!("Volume changed by {delta}%"));
                }
            }
        }

        (false, "No compatible audio controller found (wpctl/pactl)".into())
    }

    fn volume_mute() -> (bool, String) {
        if Self::command_exists("wpctl") {
            let _ = Command::new("wpctl").args(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]).output();
            return (true, "Mute toggled via wpctl".into());
        }
        if Self::command_exists("pactl") {
            let _ = Command::new("pactl").args(["set-sink-mute", "@DEFAULT_SINK@", "toggle"]).output();
            return (true, "Mute toggled via pactl".into());
        }
        (false, "No audio controller found".into())
    }

    fn media_control(cmd: &str) -> (bool, String) {
        if Self::command_exists("playerctl") {
            let res = Command::new("playerctl").arg(cmd).output();
            if let Ok(out) = res {
                if out.status.success() {
                    return (true, format!("Media {cmd} sent"));
                }
            }
        }
        (false, "playerctl not installed or no active player".into())
    }

    fn lock_session() -> (bool, String) {
        if Self::command_exists("loginctl") {
            let _ = Command::new("loginctl").arg("lock-session").output();
            return (true, "Screen locked".into());
        }
        (false, "loginctl not found".into())
    }

    fn suspend_system() -> (bool, String) {
        if Self::command_exists("systemctl") {
            info!("Suspending system via systemctl...");
            let _ = Command::new("systemctl").arg("suspend").output();
            return (true, "System suspended".into());
        }
        (false, "systemctl not found".into())
    }

    fn send_notification(title: &str, body: &str) -> (bool, String) {
        if Self::command_exists("gdbus") {
            let _ = Command::new("gdbus")
                .args([
                    "call",
                    "--session",
                    "--dest",
                    "org.freedesktop.Notifications",
                    "--object-path",
                    "/org/freedesktop/Notifications",
                    "--method",
                    "org.freedesktop.Notifications.Notify",
                    "DeskPulse",
                    "0",
                    "preferences-desktop-remote-desktop",
                    title,
                    body,
                    "[]",
                    "{}",
                    "4000",
                ])
                .output();
            return (true, "Notification sent".into());
        }

        if Self::command_exists("notify-send") {
            let _ = Command::new("notify-send").args([title, body]).output();
            return (true, "Notification sent".into());
        }

        (false, "Notification tool not available".into())
    }

    fn command_exists(name: &str) -> bool {
        Command::new("which")
            .arg(name)
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }
}
