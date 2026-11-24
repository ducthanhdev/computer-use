import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_socket_service.dart';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  @override
  Widget build(BuildContext context) {
    final socket = context.read<AgentSocketService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Virtual Trackpad Area
        const Text(
          'BÀN RÊ CHUỘT ẢO (VIRTUAL TRACKPAD)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),

        Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                final dx = (details.delta.dx * 1.5).round();
                final dy = (details.delta.dy * 1.5).round();
                socket.sendMouseMove(dx, dy);
              },
              onTap: () {
                socket.sendMouseClick('left');
              },
              child: Stack(
                children: [
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined, color: Color(0xFF475569), size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Chạm để di chuyển chuột • Bấm để click',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 50,
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => socket.sendMouseClick('left'),
                              child: const Center(
                                child: Text('Chuột Trái', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          Container(width: 1, color: const Color(0xFF1E293B)),
                          Expanded(
                            child: InkWell(
                              onTap: () => socket.sendMouseClick('right'),
                              child: const Center(
                                child: Text('Chuột Phải', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 2. Audio & Media Controls
        const Text(
          'ĐIỀU KHIỂN ÂM LƯỢNG & MEDIA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),

        Card(
          color: const Color(0xFF101726),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.volume_down,
                      label: 'Giảm',
                      onTap: () => socket.sendAction('vol_down'),
                    ),
                    _buildActionButton(
                      icon: Icons.volume_off,
                      label: 'Tắt tiếng',
                      onTap: () => socket.sendAction('vol_mute'),
                    ),
                    _buildActionButton(
                      icon: Icons.volume_up,
                      label: 'Tăng',
                      onTap: () => socket.sendAction('vol_up'),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B), height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.skip_previous,
                      label: 'Bài trước',
                      onTap: () => socket.sendAction('media_prev'),
                    ),
                    _buildActionButton(
                      icon: Icons.play_arrow,
                      label: 'Play/Pause',
                      onTap: () => socket.sendAction('media_play_pause'),
                    ),
                    _buildActionButton(
                      icon: Icons.skip_next,
                      label: 'Bài tiếp',
                      onTap: () => socket.sendAction('media_next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 3. Power & System Actions
        const Text(
          'HỆ THỐNG & NGUỒN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x33F59E0B),
                  foregroundColor: const Color(0xFFF59E0B),
                  side: const BorderSide(color: Color(0x66F59E0B)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  socket.sendAction('lock_screen');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã gửi lệnh khóa màn hình PC')),
                  );
                },
                icon: const Icon(Icons.lock_outline),
                label: const Text('Khóa màn hình', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x33F43F5E),
                  foregroundColor: const Color(0xFFF43F5E),
                  side: const BorderSide(color: Color(0x66F43F5E)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF0F172A),
                      title: const Text('Xác nhận chế độ ngủ', style: TextStyle(color: Colors.white)),
                      content: const Text('Bạn có chắc chắn muốn đưa máy tính vào chế độ Sleep?', style: TextStyle(color: Color(0xFF94A3B8))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            socket.sendAction('suspend');
                          },
                          child: const Text('Ngủ (Sleep)'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.bedtime_outlined),
                label: const Text('Chế độ ngủ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF06B6D4),
            side: const BorderSide(color: Color(0x6606B6D4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            socket.sendAction('ping_notify');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã gửi thông báo đến Desktop PC!')),
            );
          },
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Gửi thông báo test lên màn hình PC'),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x331E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33334155)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF06B6D4), size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
