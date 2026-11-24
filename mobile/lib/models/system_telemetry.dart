// System Telemetry Model for Flutter
class SystemTelemetry {
  final int timestamp;
  final CpuInfo cpu;
  final MemoryInfo memory;
  final List<DiskInfo> disks;
  final NetworkInfo network;
  final BatteryInfo battery;
  final UptimeInfo uptime;
  final HostSystemInfo system;

  SystemTelemetry({
    required this.timestamp,
    required this.cpu,
    required this.memory,
    required this.disks,
    required this.network,
    required this.battery,
    required this.uptime,
    required this.system,
  });

  factory SystemTelemetry.fromJson(Map<String, dynamic> json) {
    return SystemTelemetry(
      timestamp: json['timestamp'] ?? 0,
      cpu: CpuInfo.fromJson(json['cpu'] ?? {}),
      memory: MemoryInfo.fromJson(json['memory'] ?? {}),
      disks: (json['disks'] as List? ?? [])
          .map((d) => DiskInfo.fromJson(d))
          .toList(),
      network: NetworkInfo.fromJson(json['network'] ?? {}),
      battery: BatteryInfo.fromJson(json['battery'] ?? {}),
      uptime: UptimeInfo.fromJson(json['uptime'] ?? {}),
      system: HostSystemInfo.fromJson(json['system'] ?? {}),
    );
  }
}

class CpuInfo {
  final double percent;
  final int coresCount;
  final List<double> cores;
  final double? temperatureC;
  final int frequencyMhz;

  CpuInfo({
    required this.percent,
    required this.coresCount,
    required this.cores,
    this.temperatureC,
    required this.frequencyMhz,
  });

  factory CpuInfo.fromJson(Map<String, dynamic> json) {
    return CpuInfo(
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      coresCount: json['cores_count'] ?? 1,
      cores: (json['cores'] as List? ?? [])
          .map((c) => (c as num).toDouble())
          .toList(),
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      frequencyMhz: json['frequency_mhz'] ?? 0,
    );
  }
}

class MemoryInfo {
  final double totalMb;
  final double usedMb;
  final double freeMb;
  final double percent;
  final double swapTotalMb;
  final double swapUsedMb;
  final double swapPercent;

  MemoryInfo({
    required this.totalMb,
    required this.usedMb,
    required this.freeMb,
    required this.percent,
    required this.swapTotalMb,
    required this.swapUsedMb,
    required this.swapPercent,
  });

  factory MemoryInfo.fromJson(Map<String, dynamic> json) {
    return MemoryInfo(
      totalMb: (json['total_mb'] as num?)?.toDouble() ?? 0.0,
      usedMb: (json['used_mb'] as num?)?.toDouble() ?? 0.0,
      freeMb: (json['free_mb'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      swapTotalMb: (json['swap_total_mb'] as num?)?.toDouble() ?? 0.0,
      swapUsedMb: (json['swap_used_mb'] as num?)?.toDouble() ?? 0.0,
      swapPercent: (json['swap_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DiskInfo {
  final String name;
  final String mountPoint;
  final double totalGb;
  final double usedGb;
  final double freeGb;
  final double percent;

  DiskInfo({
    required this.name,
    required this.mountPoint,
    required this.totalGb,
    required this.usedGb,
    required this.freeGb,
    required this.percent,
  });

  factory DiskInfo.fromJson(Map<String, dynamic> json) {
    return DiskInfo(
      name: json['name'] ?? '',
      mountPoint: json['mount_point'] ?? '/',
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      usedGb: (json['used_gb'] as num?)?.toDouble() ?? 0.0,
      freeGb: (json['free_gb'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NetworkInfo {
  final double downloadKbps;
  final double uploadKbps;
  final double totalRxMb;
  final double totalTxMb;

  NetworkInfo({
    required this.downloadKbps,
    required this.uploadKbps,
    required this.totalRxMb,
    required this.totalTxMb,
  });

  factory NetworkInfo.fromJson(Map<String, dynamic> json) {
    return NetworkInfo(
      downloadKbps: (json['download_kbps'] as num?)?.toDouble() ?? 0.0,
      uploadKbps: (json['upload_kbps'] as num?)?.toDouble() ?? 0.0,
      totalRxMb: (json['total_rx_mb'] as num?)?.toDouble() ?? 0.0,
      totalTxMb: (json['total_tx_mb'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BatteryInfo {
  final bool hasBattery;
  final int percent;
  final String status;

  BatteryInfo({
    required this.hasBattery,
    required this.percent,
    required this.status,
  });

  factory BatteryInfo.fromJson(Map<String, dynamic> json) {
    return BatteryInfo(
      hasBattery: json['has_battery'] ?? false,
      percent: json['percent'] ?? 0,
      status: json['status'] ?? 'No Battery',
    );
  }
}

class UptimeInfo {
  final int seconds;
  final String formatted;

  UptimeInfo({required this.seconds, required this.formatted});

  factory UptimeInfo.fromJson(Map<String, dynamic> json) {
    return UptimeInfo(
      seconds: json['seconds'] ?? 0,
      formatted: json['formatted'] ?? '0s',
    );
  }
}

class HostSystemInfo {
  final String hostname;
  final String osName;
  final String kernel;
  final String arch;

  HostSystemInfo({
    required this.hostname,
    required this.osName,
    required this.kernel,
    required this.arch,
  });

  factory HostSystemInfo.fromJson(Map<String, dynamic> json) {
    return HostSystemInfo(
      hostname: json['hostname'] ?? 'Desktop PC',
      osName: json['os_name'] ?? 'Linux',
      kernel: json['kernel'] ?? '',
      arch: json['arch'] ?? '',
    );
  }
}

class ProcessItem {
  final int pid;
  final String name;
  final String user;
  final double cpu;
  final double mem;

  ProcessItem({
    required this.pid,
    required this.name,
    required this.user,
    required this.cpu,
    required this.mem,
  });

  factory ProcessItem.fromJson(Map<String, dynamic> json) {
    return ProcessItem(
      pid: json['pid'] ?? 0,
      name: json['name'] ?? '',
      user: json['user'] ?? '',
      cpu: (json['cpu'] as num?)?.toDouble() ?? 0.0,
      mem: (json['mem'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
