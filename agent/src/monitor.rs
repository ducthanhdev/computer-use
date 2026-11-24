use std::fs;
use std::time::{SystemTime, UNIX_EPOCH};
use sysinfo::{Components, Disks, Networks, System};

use crate::models::{
    BatteryInfo, CpuInfo, DiskInfo, HostSystemInfo, MemoryInfo, NetworkInfo, ProcessItem,
    SystemTelemetry, UptimeInfo,
};

pub struct TelemetryCollector {
    sys: System,
    disks: Disks,
    networks: Networks,
    components: Components,
    last_rx: u64,
    last_tx: u64,
    last_sample_time: SystemTime,
}

impl TelemetryCollector {
    pub fn new() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();
        let disks = Disks::new_with_refreshed_list();
        let networks = Networks::new_with_refreshed_list();
        let components = Components::new_with_refreshed_list();

        let (rx, tx) = Self::sum_network_bytes(&networks);

        Self {
            sys,
            disks,
            networks,
            components,
            last_rx: rx,
            last_tx: tx,
            last_sample_time: SystemTime::now(),
        }
    }

    fn sum_network_bytes(networks: &Networks) -> (u64, u64) {
        let mut rx = 0;
        let mut tx = 0;
        for (iface, data) in networks.iter() {
            if iface != "lo" {
                rx += data.total_received();
                tx += data.total_transmitted();
            }
        }
        (rx, tx)
    }

    pub fn sample(&mut self) -> SystemTelemetry {
        self.sys.refresh_cpu_usage();
        self.sys.refresh_memory();
        self.disks.refresh_list();
        self.networks.refresh();
        self.components.refresh_list();

        let now = SystemTime::now();
        let timestamp = now
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        // 1. CPU
        let cpus = self.sys.cpus();
        let global_cpu = self.sys.global_cpu_info().cpu_usage();
        let cores: Vec<f32> = cpus.iter().map(|c| c.cpu_usage()).collect();
        let freq = cpus.first().map(|c| c.frequency()).unwrap_or(0);

        // Temperature (from sysinfo components or /sys/class/thermal fallback)
        let temp = self
            .components
            .iter()
            .find(|c| c.label().to_lowercase().contains("cpu") || c.label().to_lowercase().contains("core"))
            .map(|c| c.temperature())
            .or_else(Self::read_linux_thermal_fallback);

        let cpu_info = CpuInfo {
            percent: (global_cpu * 10.0).round() / 10.0,
            cores_count: cpus.len(),
            cores,
            temperature_c: temp.map(|t| (t * 10.0).round() / 10.0),
            frequency_mhz: freq,
        };

        // 2. Memory
        let total_mem = self.sys.total_memory() as f64 / (1024.0 * 1024.0);
        let used_mem = self.sys.used_memory() as f64 / (1024.0 * 1024.0);
        let free_mem = (total_mem - used_mem).max(0.0);
        let mem_pct = if total_mem > 0.0 {
            ((used_mem / total_mem) * 100.0) as f32
        } else {
            0.0
        };

        let total_swap = self.sys.total_swap() as f64 / (1024.0 * 1024.0);
        let used_swap = self.sys.used_swap() as f64 / (1024.0 * 1024.0);
        let swap_pct = if total_swap > 0.0 {
            ((used_swap / total_swap) * 100.0) as f32
        } else {
            0.0
        };

        let mem_info = MemoryInfo {
            total_mb: (total_mem * 10.0).round() / 10.0,
            used_mb: (used_mem * 10.0).round() / 10.0,
            free_mb: (free_mem * 10.0).round() / 10.0,
            percent: (mem_pct * 10.0).round() / 10.0,
            swap_total_mb: (total_swap * 10.0).round() / 10.0,
            swap_used_mb: (used_swap * 10.0).round() / 10.0,
            swap_percent: (swap_pct * 10.0).round() / 10.0,
        };

        // 3. Disks
        let disk_info: Vec<DiskInfo> = self
            .disks
            .iter()
            .map(|d| {
                let total = d.total_space() as f64 / (1024.0 * 1024.0 * 1024.0);
                let free = d.available_space() as f64 / (1024.0 * 1024.0 * 1024.0);
                let used = (total - free).max(0.0);
                let pct = if total > 0.0 {
                    ((used / total) * 100.0) as f32
                } else {
                    0.0
                };
                DiskInfo {
                    name: d.name().to_string_lossy().to_string(),
                    mount_point: d.mount_point().to_string_lossy().to_string(),
                    total_gb: (total * 10.0).round() / 10.0,
                    used_gb: (used * 10.0).round() / 10.0,
                    free_gb: (free * 10.0).round() / 10.0,
                    percent: (pct * 10.0).round() / 10.0,
                }
            })
            .collect();

        // 4. Network Rates
        let (curr_rx, curr_tx) = Self::sum_network_bytes(&self.networks);
        let dt = now
            .duration_since(self.last_sample_time)
            .unwrap_or_default()
            .as_secs_f64()
            .max(0.001);

        let down_kbps = ((curr_rx.saturating_sub(self.last_rx)) as f64 / 1024.0) / dt;
        let up_kbps = ((curr_tx.saturating_sub(self.last_tx)) as f64 / 1024.0) / dt;

        self.last_rx = curr_rx;
        self.last_tx = curr_tx;
        self.last_sample_time = now;

        let net_info = NetworkInfo {
            download_kbps: (down_kbps * 10.0).round() / 10.0,
            upload_kbps: (up_kbps * 10.0).round() / 10.0,
            total_rx_mb: ((curr_rx as f64 / (1024.0 * 1024.0)) * 10.0).round() / 10.0,
            total_tx_mb: ((curr_tx as f64 / (1024.0 * 1024.0)) * 10.0).round() / 10.0,
        };

        // 5. Battery
        let battery = Self::read_battery();

        // 6. Uptime
        let uptime_sec = System::uptime();
        let uptime_info = UptimeInfo {
            seconds: uptime_sec,
            formatted: Self::format_uptime(uptime_sec),
        };

        // 7. System Info
        let sys_info = HostSystemInfo {
            hostname: System::host_name().unwrap_or_else(|| "Linux-PC".into()),
            os_name: System::long_os_version().unwrap_or_else(|| "Linux".into()),
            kernel: System::kernel_version().unwrap_or_else(|| "".into()),
            arch: System::cpu_arch().unwrap_or_else(|| "".into()),
        };

        SystemTelemetry {
            timestamp,
            cpu: cpu_info,
            memory: mem_info,
            disks: disk_info,
            network: net_info,
            battery,
            uptime: uptime_info,
            system: sys_info,
        }
    }

    pub fn get_processes(&mut self, limit: usize, sort_by_mem: bool) -> Vec<ProcessItem> {
        self.sys.refresh_processes();
        let mut list: Vec<ProcessItem> = self
            .sys
            .processes()
            .iter()
            .map(|(pid, p)| ProcessItem {
                pid: pid.as_u32(),
                name: p.name().to_string(),
                user: p.user_id().map(|u| u.to_string()).unwrap_or_else(|| "".into()),
                cpu: (p.cpu_usage() * 10.0).round() / 10.0,
                mem: ((p.memory() as f64 / (1024.0 * 1024.0)) * 10.0).round() as f32 / 10.0,
            })
            .collect();

        if sort_by_mem {
            list.sort_by(|a, b| b.mem.partial_cmp(&a.mem).unwrap_or(std::cmp::Ordering::Equal));
        } else {
            list.sort_by(|a, b| b.cpu.partial_cmp(&a.cpu).unwrap_or(std::cmp::Ordering::Equal));
        }

        list.into_iter().take(limit).collect()
    }

    fn read_battery() -> BatteryInfo {
        let pwr = "/sys/class/power_supply";
        if let Ok(entries) = fs::read_dir(pwr) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("BAT") {
                    let cap_file = entry.path().join("capacity");
                    let stat_file = entry.path().join("status");
                    if let Ok(cap_str) = fs::read_to_string(cap_file) {
                        if let Ok(percent) = cap_str.trim().parse::<u8>() {
                            let status = fs::read_to_string(stat_file)
                                .unwrap_or_else(|_| "Unknown".into())
                                .trim()
                                .to_string();
                            return BatteryInfo {
                                has_battery: true,
                                percent,
                                status,
                            };
                        }
                    }
                }
            }
        }
        BatteryInfo {
            has_battery: false,
            percent: 0,
            status: "No Battery".into(),
        }
    }

    fn read_linux_thermal_fallback() -> Option<f32> {
        let thermal_dir = "/sys/class/thermal";
        if let Ok(entries) = fs::read_dir(thermal_dir) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("thermal_zone") {
                    let temp_path = entry.path().join("temp");
                    if let Ok(val_str) = fs::read_to_string(temp_path) {
                        if let Ok(val) = val_str.trim().parse::<f32>() {
                            let c = if val > 1000.0 { val / 1000.0 } else { val };
                            if (10.0..=115.0).contains(&c) {
                                return Some(c);
                            }
                        }
                    }
                }
            }
        }
        None
    }

    fn format_uptime(seconds: u64) -> String {
        let days = seconds / 86400;
        let hours = (seconds % 86400) / 3600;
        let minutes = (seconds % 3600) / 60;
        let secs = seconds % 60;

        if days > 0 {
            format!("{days}d {hours}h {minutes}m")
        } else if hours > 0 {
            format!("{hours}h {minutes}m {secs}s")
        } else {
            format!("{minutes}m {secs}s")
        }
    }
}
