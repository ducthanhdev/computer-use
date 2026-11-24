import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_socket_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<AgentSocketService>();
    final telemetry = socket.telemetry;

    if (telemetry == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF06B6D4)),
            const SizedBox(height: 16),
            Text(
              socket.status == ConnectionStatus.connecting
                  ? 'Đang kết nối đến ${socket.host}:${socket.port}...'
                  : 'Mất kết nối với máy tính\nĐang tự động thử lại...',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. CPU Real-time Waveform Card
        _buildCpuCard(context, telemetry, socket.cpuHistory),

        const SizedBox(height: 12),

        // 2. Memory Card
        _buildMemoryCard(context, telemetry),

        const SizedBox(height: 12),

        // 3. Network Speeds
        _buildNetworkCard(context, telemetry),

        const SizedBox(height: 12),

        // 4. Disks Card
        _buildDisksCard(context, telemetry),

        const SizedBox(height: 12),

        // 5. Battery & Hardware Info
        if (telemetry.battery.hasBattery) _buildBatteryCard(context, telemetry),
      ],
    );
  }

  Widget _buildCpuCard(BuildContext context, dynamic telemetry, List<FlSpot> spots) {
    final cpu = telemetry.cpu;
    final color = cpu.percent >= 85
        ? const Color(0xFFF43F5E)
        : (cpu.percent >= 65 ? const Color(0xFFF59E0B) : const Color(0xFF06B6D4));

    return Card(
      color: const Color(0xFF101726),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.memory, color: Color(0xFF06B6D4), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'BỘ VI XỬ LÝ (CPU)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (cpu.temperatureC != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x33F59E0B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${cpu.temperatureC}°C 🔥',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      '${cpu.coresCount} cores',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${cpu.percent.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color),
                ),
                const Text(
                  ' %',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
                const Spacer(),
                Text(
                  '${cpu.frequencyMhz} MHz',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Live fl_chart wave
            SizedBox(
              height: 70,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineBarData(
                      spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard(BuildContext context, dynamic telemetry) {
    final mem = telemetry.memory;
    final color = mem.percent >= 85
        ? const Color(0xFFF43F5E)
        : (mem.percent >= 65 ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8));

    return Card(
      color: const Color(0xFF101726),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storage, color: Color(0xFF38BDF8), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'BỘ NHỚ RAM',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(mem.usedMb / 1024).toStringAsFixed(1)} / ${(mem.totalMb / 1024).toStringAsFixed(1)} GB',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${mem.percent.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
                const Spacer(),
                if (mem.swapTotalMb > 0)
                  Text(
                    'Swap: ${(mem.swapUsedMb / 1024).toStringAsFixed(1)} GB',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (mem.percent / 100).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF1E293B),
                color: color,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkCard(BuildContext context, dynamic telemetry) {
    final net = telemetry.network;

    return Card(
      color: const Color(0xFF101726),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wifi, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 8),
                Text(
                  'LƯU LƯỢNG MẠNG',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x330F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x33334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('↓ Tải xuống', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          _formatSpeed(net.downloadKbps),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x330F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x33334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('↑ Tải lên', style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          _formatSpeed(net.uploadKbps),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisksCard(BuildContext context, dynamic telemetry) {
    final disks = telemetry.disks;

    return Card(
      color: const Color(0xFF101726),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.album_outlined, color: Color(0xFFA855F7), size: 20),
                SizedBox(width: 8),
                Text(
                  'Ổ ĐĨA LƯU TRỮ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...disks.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(d.mountPoint, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(
                            '${d.usedGb.toStringAsFixed(1)} / ${d.totalGb.toStringAsFixed(1)} GB (${d.percent.toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (d.percent / 100).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF1E293B),
                          color: const Color(0xFFA855F7),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryCard(BuildContext context, dynamic telemetry) {
    final bat = telemetry.battery;
    return Card(
      color: const Color(0xFF101726),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.battery_charging_full, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pin Laptop: ${bat.percent}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text(bat.status, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSpeed(double kbps) {
    if (kbps >= 1024) {
      return '${(kbps / 1024).toStringAsFixed(1)} MB/s';
    }
    return '${kbps.round()} KB/s';
  }
}
