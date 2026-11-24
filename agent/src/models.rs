use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemTelemetry {
    pub timestamp: u64,
    pub cpu: CpuInfo,
    pub memory: MemoryInfo,
    pub disks: Vec<DiskInfo>,
    pub network: NetworkInfo,
    pub battery: BatteryInfo,
    pub uptime: UptimeInfo,
    pub system: HostSystemInfo,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CpuInfo {
    pub percent: f32,
    pub cores_count: usize,
    pub cores: Vec<f32>,
    pub temperature_c: Option<f32>,
    pub frequency_mhz: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryInfo {
    pub total_mb: f64,
    pub used_mb: f64,
    pub free_mb: f64,
    pub percent: f32,
    pub swap_total_mb: f64,
    pub swap_used_mb: f64,
    pub swap_percent: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskInfo {
    pub name: String,
    pub mount_point: String,
    pub total_gb: f64,
    pub used_gb: f64,
    pub free_gb: f64,
    pub percent: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkInfo {
    pub download_kbps: f64,
    pub upload_kbps: f64,
    pub total_rx_mb: f64,
    pub total_tx_mb: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatteryInfo {
    pub has_battery: bool,
    pub percent: u8,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UptimeInfo {
    pub seconds: u64,
    pub formatted: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HostSystemInfo {
    pub hostname: String,
    pub os_name: String,
    pub kernel: String,
    pub arch: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessItem {
    pub pid: u32,
    pub name: String,
    pub user: String,
    pub cpu: f32,
    pub mem: f32,
}

/// Messages sent from Flutter client to Rust agent
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum ClientCommand {
    #[serde(rename = "action")]
    Action { action: String },

    #[serde(rename = "mouse_move")]
    MouseMove { dx: i32, dy: i32 },

    #[serde(rename = "mouse_click")]
    MouseClick { button: String }, // "left", "right", "middle"

    #[serde(rename = "mouse_scroll")]
    MouseScroll { dy: i32 },

    #[serde(rename = "key_press")]
    KeyPress { key: String },

    #[serde(rename = "ping")]
    Ping,
}

/// Messages sent from Rust agent to Flutter client
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum ServerEvent {
    #[serde(rename = "telemetry")]
    Telemetry(SystemTelemetry),

    #[serde(rename = "processes")]
    Processes(Vec<ProcessItem>),

    #[serde(rename = "action_result")]
    ActionResult { success: bool, message: String },

    #[serde(rename = "pong")]
    Pong { server_time: u64 },
}
