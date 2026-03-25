import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'heatmap_dashboard.dart';
import 'admin_reports_tab.dart';
import 'admin_missions_tab.dart';
import '../services/auth_service.dart';

class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const MergedInboxTab(),
    const AdminMissionsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('AIDWISE COMMAND', style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 16,
              shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)],
            )),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary, size: 20),
            onPressed: () => AuthService().signOut(),
          )
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.background, // Match obsidian
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        elevation: 20,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.all_inbox), label: 'Inboxes'),
          BottomNavigationBarItem(icon: Icon(Icons.rocket_launch), label: 'Missions'),
        ],
      ),
    );
  }
}

class MergedInboxTab extends StatelessWidget {
  const MergedInboxTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            dividerColor: Colors.transparent,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            tabs: const [
              Tab(text: 'AI FIELD REPORTS'),
              Tab(text: 'OFFICE MANUAL'),
            ],
          ),
          const SizedBox(height: 10),
          const Expanded(
            child: TabBarView(
              children: [
                HeatmapDashboard(showAppBar: false),
                AdminReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
