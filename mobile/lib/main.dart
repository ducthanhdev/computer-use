import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/processes_screen.dart';
import 'screens/remote_screen.dart';
import 'screens/settings_sheet.dart';
import 'services/agent_socket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AgentSocketService(),
      child: const DeskPulseApp(),
    ),
  );
}

class DeskPulseApp extends StatelessWidget {
  const DeskPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeskPulse Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07090E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF06B6D4),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF101726),
          onSurface: Color(0xFFF8FAFC),
        ),
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    RemoteScreen(),
    ProcessesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<AgentSocketService>();
    final telemetry = socket.telemetry;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF07090E).withOpacity(0.95),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              telemetry?.system.hostname ?? 'DeskPulse PC',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              telemetry != null
                  ? '${telemetry.system.osName} • ⏱ ${telemetry.uptime.formatted}'
                  : 'Đang kết nối: ${socket.host}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          // Connection status badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusBg(socket.status),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getStatusColor(socket.status).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(socket.status),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(socket.status, socket.latencyMs),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(socket.status),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SettingsSheet(),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF0A0E17),
        indicatorColor: const Color(0x3306B6D4),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF06B6D4)),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.mouse_outlined),
            selectedIcon: Icon(Icons.mouse, color: Color(0xFF06B6D4)),
            label: 'Bàn rê & Phím',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: Color(0xFF06B6D4)),
            label: 'Tiến trình',
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return const Color(0xFF10B981);
      case ConnectionStatus.connecting:
        return const Color(0xFFF59E0B);
      case ConnectionStatus.disconnected:
        return const Color(0xFFF43F5E);
    }
  }

  Color _getStatusBg(ConnectionStatus status) {
    return _getStatusColor(status).withOpacity(0.12);
  }

  String _getStatusText(ConnectionStatus status, int latency) {
    switch (status) {
      case ConnectionStatus.connected:
        return latency > 0 ? '${latency}ms' : 'LIVE';
      case ConnectionStatus.connecting:
        return 'CONNECT';
      case ConnectionStatus.disconnected:
        return 'OFFLINE';
    }
  }
}
