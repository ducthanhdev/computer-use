import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/system_telemetry.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class AgentSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  String _host = '192.168.1.50';
  int _port = 8765;
  String get host => _host;
  int get port => _port;

  SystemTelemetry? _telemetry;
  SystemTelemetry? get telemetry => _telemetry;

  int _latencyMs = 0;
  int get latencyMs => _latencyMs;
  int _lastPingSent = 0;

  // Rolling chart historical points (Max 25 points)
  final List<FlSpot> _cpuHistory = [];
  List<FlSpot> get cpuHistory => _cpuHistory;

  final List<FlSpot> _ramHistory = [];
  List<FlSpot> get ramHistory => _ramHistory;

  double _timeIndex = 0;

  AgentSocketService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString('server_host') ?? '192.168.1.50';
    _port = prefs.getInt('server_port') ?? 8765;
    notifyListeners();
    connect();
  }

  Future<void> updateServerAddress(String newHost, int newPort) async {
    _host = newHost.trim();
    _port = newPort;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_host', _host);
    await prefs.setInt('server_port', _port);
    connect();
  }

  void connect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();

    _status = ConnectionStatus.connecting;
    notifyListeners();

    final wsUrl = Uri.parse('ws://$_host:$_port/ws');

    try {
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (message) {
          if (_status != ConnectionStatus.connected) {
            _status = ConnectionStatus.connected;
            _startPingLoop();
            notifyListeners();
          }
          _handleMessage(message);
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (err) {
          _handleDisconnect();
        },
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (_status != ConnectionStatus.disconnected) {
      _status = ConnectionStatus.disconnected;
      notifyListeners();
    }
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      connect();
    });
  }

  void _startPingLoop() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_status == ConnectionStatus.connected) {
        _lastPingSent = DateTime.now().millisecondsSinceEpoch;
        sendRaw({'type': 'ping'});
      }
    });
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final type = data['type'];
      final payload = data['payload'];

      if (type == 'telemetry' && payload != null) {
        _telemetry = SystemTelemetry.fromJson(payload);
        
        // Update live charts
        _timeIndex += 1;
        _cpuHistory.add(FlSpot(_timeIndex, _telemetry!.cpu.percent));
        _ramHistory.add(FlSpot(_timeIndex, _telemetry!.memory.percent));
        if (_cpuHistory.length > 25) _cpuHistory.removeAt(0);
        if (_ramHistory.length > 25) _ramHistory.removeAt(0);

        notifyListeners();
      } else if (type == 'pong') {
        if (_lastPingSent > 0) {
          _latencyMs = DateTime.now().millisecondsSinceEpoch - _lastPingSent;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  void sendRaw(Map<String, dynamic> data) {
    if (_status == ConnectionStatus.connected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void sendAction(String action) {
    sendRaw({
      'type': 'action',
      'payload': {'action': action}
    });
  }

  void sendMouseMove(int dx, int dy) {
    sendRaw({
      'type': 'mouse_move',
      'payload': {'dx': dx, 'dy': dy}
    });
  }

  void sendMouseClick(String button) {
    sendRaw({
      'type': 'mouse_click',
      'payload': {'button': button}
    });
  }

  void sendMouseScroll(int dy) {
    sendRaw({
      'type': 'mouse_scroll',
      'payload': {'dy': dy}
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
