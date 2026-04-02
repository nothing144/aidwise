import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/offline_sync_service.dart';
import '../services/offline/offline_queue_service.dart';
import '../services/offline/bluetooth_mesh_service.dart';
import '../models/offline/offline_message.dart';
import 'package:permission_handler/permission_handler.dart';
import 'volunteer_offline_mission_screen.dart';
import 'volunteer_terminal.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  State<VolunteerDashboardScreen> createState() => _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  final _syncService = OfflineSyncService();
  String? _lastHandledMeshId;
  late StreamSubscription<List<ConnectivityResult>> _connSub;
  bool _isOffline = false;
  final Map<String, bool> _acknowledging = {};

  @override
  void initState() {
    super.initState();
    _initMeshDiscovery();
    _syncService.receivedMission.addListener(_onMissionReceived);
    _connSub = Connectivity().onConnectivityChanged.listen((res) {
      if (mounted) setState(() => _isOffline = res.isEmpty || res.first == ConnectivityResult.none);
    });
    Connectivity().checkConnectivity().then((res) {
      if (mounted) setState(() => _isOffline = res.isEmpty || res.first == ConnectivityResult.none);
    });
  }

  Future<void> _initMeshDiscovery() async {
    final user = FirebaseAuth.instance.currentUser;
    await _syncService.init(userName: user?.displayName ?? 'Volunteer', role: 'Volunteer');
    
    // Request permissions for Offline Mesh Navigation
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();
    
    // Start scanning for Admin or Mules
    await _syncService.startDiscovery();
  }

  void _onMissionReceived() {
    final missionData = _syncService.receivedMission.value;
    if (missionData == null || !mounted) return;

    // Prevent infinite loop: only handle each unique mission once
    final meshId = missionData['_meshId']?.toString();
    if (meshId == _lastHandledMeshId) return;
    _lastHandledMeshId = meshId;

    // Clear the notifier so it doesn't re-trigger on hot reload / re-listen
    _syncService.receivedMission.value = null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerOfflineMissionScreen(missionData: missionData),
      ),
    );
  }

  @override
  void dispose() {
    _connSub.cancel();
    _syncService.receivedMission.removeListener(_onMissionReceived);
    _syncService.stopDiscovery();
    super.dispose();
  }

  Widget _buildOfflineBanner() {
    if (!_isOffline) return const SizedBox.shrink();
    return Container(
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
              Text('$count updates queued', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          );
        },
      ),
    );
  }

  void _acknowledgeMission(OfflineMessage msg) async {
    setState(() => _acknowledging[msg.msgId] = true);
    
    final ackMsg = OfflineMessage(
      msgId: DateTime.now().millisecondsSinceEpoch.toString(), // unique id
      fromNodeId: FirebaseAuth.instance.currentUser!.uid,
      toNodeId: msg.fromNodeId,
      payload: {'action': 'ack', 'refId': msg.msgId},
      type: MessageType.ack,
      timestamp: DateTime.now(),
      ttl: const Duration(minutes: 60),
      seenByNodes: [FirebaseAuth.instance.currentUser!.uid],
    );

    try {
      await GetIt.I<BluetoothMeshService>().sendMessage(ackMsg);
      await GetIt.I<OfflineQueueService>().markAcked(msg.msgId);
      // It stays green
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send acknowledgment — will retry when in range')));
        setState(() => _acknowledging[msg.msgId] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MISSION BOARD', style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => AuthService().signOut()),
        ],
      ),
      body: Column(
        children: [
          _buildOfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                            builder: (ctx, snap) {
                              if (snap.hasError) return const Text('Hello, Volunteer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white));
                              if (snap.connectionState == ConnectionState.waiting) return const Text('Loading...', style: TextStyle(color: Colors.white70));
                              
                              String name = 'Volunteer';
                              if (snap.hasData && snap.data!.exists && snap.data!.data() != null) {
                                final data = snap.data!.data() as Map<String, dynamic>;
                                name = data.containsKey('displayName') ? data['displayName'] : 'Volunteer';
                              }
                              return Text('Hello, $name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white));
                            },
                          ),
                          const SizedBox(height: 4),
                          Text('Status: ON DUTY', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)])),
                        ],
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('missions')
                            .where('assignedVolunteerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                            .where('status', isEqualTo: 'Completed')
                            .snapshots(),
                        builder: (ctx, snap) {
                          int completedCount = snap.data?.docs.length ?? 0;
                          int impactXP = completedCount * 100;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: AppTheme.primary)),
                            child: Text('$impactXP', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                          );
                        },
                      ),
                    ],
                  ),

                  // MESH MISSIONS Section
                  ValueListenableBuilder<int>(
                    valueListenable: GetIt.I<OfflineQueueService>().pendingCount,
                    builder: (context, val, child) {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return const SizedBox.shrink();
                      
                      final offlineDispatches = GetIt.I<OfflineQueueService>().getAllUnacked()
                          .where((m) => m.type == MessageType.dispatch && m.toNodeId == uid).toList();
                          
                      if (offlineDispatches.isEmpty) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),
                          const Text('OFFLINE MESH DISPATCHES', style: TextStyle(color: AppTheme.urgencyHigh, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          const SizedBox(height: 16),
                          ...offlineDispatches.map((msg) {
                             final mins = DateTime.now().difference(msg.timestamp).inMinutes;
                             final payload = msg.payload;
                             final isAcking = _acknowledging[msg.msgId] ?? false;
                             final isAcked = msg.acked;
                             
                             return Padding(
                               padding: const EdgeInsets.only(bottom: 16.0),
                               child: _buildMissionCard(
                                 context: context,
                                 title: payload['title'] ?? 'Priority Mission',
                                 location: payload['location'] ?? 'Unknown Location',
                                 distance: 'Mesh Assigned',
                                 urgencyInfo: 'Critical Priority',
                                 color: AppTheme.urgencyHigh,
                                 subtitle: 'Received via mesh · $mins min ago',
                                 bottomAction: ElevatedButton(
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: isAcked ? Colors.green : AppTheme.primary,
                                     foregroundColor: Colors.black,
                                   ),
                                   onPressed: (isAcking || isAcked) ? null : () => _acknowledgeMission(msg),
                                   child: isAcking ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : 
                                          isAcked ? const Text('Acknowledged ✓') : const Text('Acknowledge'),
                                 ),
                                 onTap: () {} // Offline mission viewer logic goes here
                               ),
                             );
                          }).toList(),
                        ],
                      );
                    }
                  ),

                  const SizedBox(height: 32),
                  const Text('AI PRIORITIZED FOR YOU', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('missions')
                        .where('assignedVolunteerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .where('status', isEqualTo: 'Pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(color: AppTheme.primary);
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text('Standby... awaiting AI dispatch.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
                        );
                      }

                      return Column(
                        children: snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildMissionCard(
                              context: context,
                              title: data['title'] ?? 'Priority Mission',
                              location: data['location'] ?? 'Unknown Location',
                              distance: 'AI Assigned',
                              urgencyInfo: 'Critical Priority',
                              color: AppTheme.textPrimary,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => VolunteerTerminalScreen(
                                  missionId: doc.id,
                                  title: data['title'] ?? 'Priority Mission',
                                  location: data['location'] ?? 'Unknown Location',
                                  latitude: data['latitude']?.toDouble() ?? 28.6139,
                                  longitude: data['longitude']?.toDouble() ?? 77.2090,
                                  reportId: data['reportId'],
                                )));
                              }
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('OPEN MISSIONS NEARBY (POOL)', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('missions')
                        .where('status', isEqualTo: 'Open')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox();
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Text('No open missions at this time.', style: TextStyle(color: AppTheme.textSecondary));
                      }

                      return Column(
                        children: snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildMissionCard(
                              context: context,
                              title: data['title'] ?? 'Open Task',
                              location: data['location'] ?? 'Unknown Location',
                              distance: 'Nearby',
                              urgencyInfo: 'Medium Priority',
                              color: AppTheme.urgencyMedium,
                              onTap: () {}
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard({
    required BuildContext context,
    required String title,
    required String location,
    required String distance,
    required String urgencyInfo,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
    Widget? bottomAction,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, color: color, size: 16),
                const SizedBox(width: 4),
                Text('$location • $distance', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
            if (subtitle != null) Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Text(subtitle, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(urgencyInfo, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                if (bottomAction != null) bottomAction,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
