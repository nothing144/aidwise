import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import '../theme/app_theme.dart';
import 'heatmap_dashboard.dart';
import 'admin_reports_tab.dart';
import 'admin_missions_tab.dart';
import 'analytics_dashboard_tab.dart';
import 'data_vault_tab.dart';
import 'admin_mesh_inbox_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/offline_sync_service.dart';
import '../services/offline/bluetooth_mesh_service.dart';
import '../models/offline/node_info.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> {
  int _currentIndex = 0;
  final OfflineSyncService _syncService = OfflineSyncService();
  late StreamSubscription<List<ConnectivityResult>> _connSub;
  bool _isOffline = false;
  Timer? _statusUpdateTimer;

  // Mocking notifiers that weren't strictly added to the service files yet
  final ValueNotifier<bool> _dummyBluetoothNotifier = ValueNotifier(true);
  final ValueNotifier<List<dynamic>> _dummyConflictsNotifier = ValueNotifier([]);

  @override
  void initState() {
    super.initState();
    _initMeshAdvertising();
    
    _connSub = Connectivity().onConnectivityChanged.listen((res) {
      if (mounted) setState(() => _isOffline = res.isEmpty || res.first == ConnectivityResult.none);
    });
    Connectivity().checkConnectivity().then((res) {
      if (mounted) setState(() => _isOffline = res.isEmpty || res.first == ConnectivityResult.none);
    });
    
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initMeshAdvertising() async {
    await _syncService.init(userName: 'AdminHQ', role: 'Admin');
    // Request permissions then auto-advertise
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();
    await _syncService.startAdvertising();
    
    // Silently fetch and cache active volunteers if online
    if (await OfflineSyncService.hasInternet()) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Volunteer')
            .get();
        final volunteers = snap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
        await _syncService.cacheVolunteersOffline(volunteers);
      } catch (e) {
        debugPrint('Failed to cache volunteers: $e');
      }
    }
  }

  @override
  void dispose() {
    _connSub.cancel();
    _statusUpdateTimer?.cancel();
    _syncService.stopAdvertising();
    super.dispose();
  }

  Widget _buildTopConnectivityBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _dummyBluetoothNotifier, // Ideally GetIt.I<BluetoothMeshService>().bluetoothStatusNotifier
      builder: (context, btActive, child) {
         final connectedNodes = GetIt.I<BluetoothMeshService>().routingTable.nodes.values.where((n) => n.status == NodeStatus.online).length;
         
         Color dotColor;
         String statusText;
         
         if (!_isOffline) {
           dotColor = Colors.green;
           statusText = "Online · Synced recently";
         } else if (_isOffline && btActive && connectedNodes > 0) {
           dotColor = Colors.orange;
           statusText = "Mesh mode · $connectedNodes nodes reachable";
         } else if (_isOffline && !btActive) {
           dotColor = Colors.grey;
           statusText = "Bluetooth disabled — tap to enable";
         } else {
           dotColor = Colors.red;
           statusText = "Offline · Changes saved locally";
         }

         return GestureDetector(
           onTap: () {
             if (_isOffline && !btActive) {
               // open BT settings logic would go here
             }
           },
           child: Container(
             width: double.infinity,
             padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
             color: Colors.black26,
             child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                 const SizedBox(width: 8),
                 Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
               ],
             ),
           ),
         );
      },
    );
  }

  Widget _buildConflictBanner() {
     return ValueListenableBuilder<List<dynamic>>(
       valueListenable: _dummyConflictsNotifier, // Ideally GetIt.I<SyncService>().conflictsNotifier
       builder: (context, conflicts, _) {
          if (conflicts.isEmpty) return const SizedBox.shrink();
          return MaterialBanner(
            backgroundColor: Colors.amber,
            content: Text("${conflicts.length} assignment conflicts detected after sync. Tap to resolve.", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            actions: [
              TextButton(
                onPressed: () {
                  // bottom sheet logic for conflict resolution
                },
                child: const Text('RESOLVE', style: TextStyle(color: Colors.black)),
              )
            ],
          );
       }
     );
  }

  Widget _buildOfflineNodeStatusBar() {
    final nodes = GetIt.I<BluetoothMeshService>().routingTable.nodes.values.toList();
    if (nodes.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: nodes.length,
        itemBuilder: (ctx, i) {
          final node = nodes[i];
          final secondsOffline = DateTime.now().difference(node.lastSeen).inSeconds;
          
          Color dotColor;
          if (node.status == NodeStatus.unknown) {
            dotColor = Colors.grey;
          } else if (secondsOffline < 90) {
            dotColor = Colors.green;
          } else if (secondsOffline < 300) {
            dotColor = Colors.yellow;
          } else {
            dotColor = Colors.red;
          }
          
          return GestureDetector(
            onTap: () {
              showModalBottomSheet(context: context, backgroundColor: AppTheme.surface, builder: (c) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Role: ${node.role.name.toUpperCase()}', style: const TextStyle(color: Colors.white70)),
                    Text('Last Seen: ${node.lastSeen.toLocal()}', style: const TextStyle(color: Colors.white70)),
                    Text('Reachable Via: ${node.isDirectlyReachable ? 'Direct Connection' : (node.reachableVia ?? 'Unknown')}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                  ],
                ),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(radius: 24, backgroundColor: AppTheme.primary.withValues(alpha: 0.2), child: Text(node.name.isNotEmpty ? node.name[0] : '?', style: const TextStyle(color: AppTheme.primary))),
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: AppTheme.background, width: 2))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(node.name.split(' ').first, style: const TextStyle(color: Colors.white, fontSize: 10)),
                  Text(node.role.name, style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  final List<Widget> _pages = [
    const MergedInboxTab(),
    const AdminMissionsTab(),
    const AnalyticsDashboardTab(),
    const DataVaultTab(),
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
          // Mesh Status Indicator
          ValueListenableBuilder<bool>(
            valueListenable: _syncService.isAdvertising,
            builder: (context, isAdv, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  icon: Icon(
                    isAdv ? Icons.cell_tower : Icons.bluetooth_disabled,
                    color: isAdv ? Colors.green : AppTheme.textSecondary,
                    size: 20,
                  ),
                  tooltip: isAdv ? 'Mesh: Broadcasting' : 'Mesh: Offline',
                  onPressed: () {
                    if (isAdv) {
                      _syncService.stopAdvertising();
                    } else {
                      _syncService.startAdvertising();
                    }
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary, size: 20),
            onPressed: () => AuthService().signOut(),
          )
        ],
      ),
      body: Column(
        children: [
          _buildConflictBanner(),
          _buildTopConnectivityBar(),
          if (_isOffline) _buildOfflineNodeStatusBar(),
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
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.all_inbox), label: 'Inboxes'),
          BottomNavigationBarItem(icon: Icon(Icons.rocket_launch), label: 'Missions'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'Data Vault'),
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
      length: 3,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            dividerColor: Colors.transparent,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11),
            tabs: const [
              Tab(text: 'AI FIELD REPORTS'),
              Tab(text: 'OFFICE MANUAL'),
              Tab(text: 'P2P MESH'),
            ],
          ),
          const SizedBox(height: 10),
          const Expanded(
            child: TabBarView(
              children: [
                HeatmapDashboard(showAppBar: false),
                AdminReportsTab(),
                AdminMeshInboxScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
