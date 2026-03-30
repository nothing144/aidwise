import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ai_scanner_screen.dart';
import 'my_reports_screen.dart';
import 'mesh_sync_screen.dart';
import '../services/offline_sync_service.dart';

class FieldWorkerHub extends StatefulWidget {
  const FieldWorkerHub({super.key});

  @override
  State<FieldWorkerHub> createState() => _FieldWorkerHubState();
}

class _FieldWorkerHubState extends State<FieldWorkerHub> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const AIScannerScreen(),
    const MyReportsScreen(),
    const MeshSyncScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize the sync service for this Field Worker
    OfflineSyncService().init(userName: 'FieldWorker', role: 'FieldWorker');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _pages[_currentIndex],
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
