import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import '../theme/app_theme.dart';
import 'ai_scanner_screen.dart';
import 'my_reports_screen.dart';
import 'mesh_sync_screen.dart';
import '../services/offline_sync_service.dart';
import '../services/offline/offline_queue_service.dart';

class FieldWorkerHub extends StatefulWidget {
  const FieldWorkerHub({super.key});

  @override
  State<FieldWorkerHub> createState() => _FieldWorkerHubState();
}

class _FieldWorkerHubState extends State<FieldWorkerHub> {
  int _currentIndex = 0;
  late StreamSubscription<List<ConnectivityResult>> _connSub;
  bool _isOffline = false;

  final List<Widget> _pages = [
    const AIScannerScreen(),
    const MyReportsScreen(),
    const MeshSyncScreen(),
  ];

  @override
  void initState() {
    super.initState();
    OfflineSyncService().init(userName: 'FieldWorker', role: 'FieldWorker');
    
    _connSub = Connectivity().onConnectivityChanged.listen((res) {
      if (mounted) setState(() => _isOffline = res.isEmpty || res.first == ConnectivityResult.none);
    });
    Connectivity().checkConnectivity().then((res) {
      if (mounted) setState(() => _isOffline = res.isEmpty || res.first == ConnectivityResult.none);
    });
  }

  @override
  void dispose() {
    _connSub.cancel();
    super.dispose();
  }

  Widget _buildOfflineBanner() {
    if (!_isOffline) return const SizedBox.shrink();
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: AppTheme.urgencyHigh,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: ValueListenableBuilder<int>(
          valueListenable: GetIt.I<OfflineQueueService>().pendingCount,
          builder: (context, count, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bluetooth_connected, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Offline · Mesh active', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('$count queued', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildOfflineBanner(),
          Expanded(child: _pages[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.background,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        elevation: 20,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.document_scanner), label: 'Scanner'),
          const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'My Reports'),
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: OfflineSyncService().pendingReports,
              builder: (context, reports, child) {
                return Badge(
                  isLabelVisible: reports.isNotEmpty,
                  label: Text('${reports.length}'),
                  backgroundColor: AppTheme.urgencyHigh,
                  child: const Icon(Icons.bluetooth),
                );
              },
            ),
            label: 'Mesh Sync',
          ),
        ],
      ),
    );
  }
}
