import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/system_telemetry.dart';
import '../services/agent_socket_service.dart';

class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key});

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends State<ProcessesScreen> {
  List<ProcessItem> _processes = [];
  bool _isLoading = false;
  String _sortBy = 'cpu';
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _fetchProcesses();
  }

  Future<void> _fetchProcesses() async {
    setState(() => _isLoading = true);
    final socket = context.read<AgentSocketService>();
    final url = Uri.parse('http://${socket.host}:${socket.port}/api/processes?sort=$_sortBy&limit=25');

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['processes'] as List? ?? [])
            .map((p) => ProcessItem.fromJson(p))
            .toList();
        setState(() {
          _processes = list;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _processes.where((p) {
      if (_filter.isEmpty) return true;
      return p.name.toLowerCase().contains(_filter.toLowerCase()) ||
          p.pid.toString().contains(_filter);
    }).toList();

    return Column(
      children: [
        // Top filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _filter = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm tiến trình (tên hoặc PID)...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF101726),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF06B6D4)),
                onPressed: _fetchProcesses,
              ),
            ],
          ),
        ),

        // Sort tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Theo CPU', style: TextStyle(fontSize: 12)),
                selected: _sortBy == 'cpu',
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _sortBy = 'cpu');
                    _fetchProcesses();
                  }
                },
                selectedColor: const Color(0x3306B6D4),
                labelStyle: TextStyle(color: _sortBy == 'cpu' ? const Color(0xFF06B6D4) : const Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Theo RAM', style: TextStyle(fontSize: 12)),
                selected: _sortBy == 'mem',
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _sortBy = 'mem');
                    _fetchProcesses();
                  }
                },
                selectedColor: const Color(0x3338BDF8),
                labelStyle: TextStyle(color: _sortBy == 'mem' ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),

        // Process list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101726),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                Text('PID: ${p.pid} • ${p.user}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _sortBy == 'cpu' ? const Color(0x2206B6D4) : const Color(0x2238BDF8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _sortBy == 'cpu' ? '${p.cpu}% CPU' : '${p.mem} MB RAM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _sortBy == 'cpu' ? const Color(0xFF06B6D4) : const Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
