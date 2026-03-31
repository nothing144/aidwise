import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/offline_sync_service.dart';
import '../services/offline_nav_service.dart';
import 'package:geolocator/geolocator.dart';

/// Admin's offline P2P inbox — shows reports received via Bluetooth mesh
/// that haven't been synced to Firestore yet.
class AdminMeshInboxScreen extends StatefulWidget {
  const AdminMeshInboxScreen({super.key});

  @override
  State<AdminMeshInboxScreen> createState() => _AdminMeshInboxScreenState();
}

class _AdminMeshInboxScreenState extends State<AdminMeshInboxScreen> {
  final syncService = OfflineSyncService();
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting location for compass: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_connected, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('P2P MESH INBOX', style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 14,
                    shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)],
                  )),
                  const Spacer(),
                  // Sync Status
                  ValueListenableBuilder<String>(
                    valueListenable: syncService.syncStatus,
                    builder: (context, status, _) {
                      bool isActive = status == 'ADVERTISING' || status == 'CONNECTED';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? Colors.green.withValues(alpha: 0.15) 
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isActive ? Colors.green : AppTheme.surfaceLow),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive ? Icons.cell_tower : Icons.bluetooth_disabled,
                              color: isActive ? Colors.green : AppTheme.textSecondary,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'LISTENING' : 'IDLE',
                              style: TextStyle(
                                color: isActive ? Colors.green : AppTheme.textSecondary,
                                fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Reports received via Bluetooth when offline. Tap SYNC to upload when internet is available.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            // Sync Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await syncService.trySyncQueueToFirestore();
                    if (context.mounted) {
                      final status = syncService.syncStatus.value;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(status == 'SYNC_COMPLETE' 
                            ? '✅ All reports synced to cloud!' 
                            : '⚠️ No internet or no pending reports.'),
                        backgroundColor: status == 'SYNC_COMPLETE' ? Colors.green : Colors.orangeAccent,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('SYNC TO CLOUD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Completed Mission Updates (received via mesh) ──
            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: syncService.completedMissions,
              builder: (context, completions, _) {
                if (completions.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Text('MISSION UPDATES (${completions.length})', style: const TextStyle(
                            color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5,
                          )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...completions.map((update) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_pin, color: Colors.green, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${update['_volunteerName'] ?? 'Volunteer'} — ${(update['_status'] ?? 'Done').toString().toUpperCase()}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Received via P2P Mesh • ${_formatTime(update['_completedAt'])}',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('✓ DONE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
            // Report List
            Expanded(
              child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: syncService.pendingReports,
                builder: (context, reports, _) {
                  if (reports.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox, color: AppTheme.textSecondary.withValues(alpha: 0.3), size: 56),
                          const SizedBox(height: 12),
                          Text('No offline reports pending.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('P2P reports will appear here automatically.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return _buildReportCard(report, index + 1);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, int serial) {
    String type = report['type'] ?? 'Unknown';
    String urgency = report['urgency'] ?? 'Medium';
    String location = report['location'] ?? 'N/A';
    String description = report['description'] ?? 'No description';
    double? lat = (report['latitude'] as num?)?.toDouble();
    double? lng = (report['longitude'] as num?)?.toDouble();
    String meshOrigin = report['_meshOrigin'] ?? 'Unknown';
    String meshTime = report['_meshTimestamp'] ?? '';
    
    // Calculate routing string if we have admin position and report GPS
    String routingString = '';
    if (_currentPosition != null && lat != null && lng != null) {
      routingString = OfflineNavService.getRoutingString(
          _currentPosition!.latitude, _currentPosition!.longitude, lat, lng);
    }

    Color urgencyColor = urgency == 'Critical' || urgency == 'High'
        ? AppTheme.urgencyHigh
        : AppTheme.urgencyMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.5),
              border: Border(
                left: BorderSide(color: urgencyColor, width: 3),
                top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
                right: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
                bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('#$serial', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(type.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: urgencyColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(urgency.toUpperCase(), style: TextStyle(color: urgencyColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Offline Compass Widget
                if (routingString.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.explore, color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$routingString FROM YOUR HQ',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Description
                if (description.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.surfaceLow),
                    ),
                    child: Text(description, style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.85), fontSize: 12, height: 1.4)),
                  ),
                const SizedBox(height: 10),
                // Location (Text-based with coordinates)
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppTheme.urgencyHigh, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(location, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ),
                  ],
                ),
                if (lat != null && lng != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.gps_fixed, color: AppTheme.textSecondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                
                // Metadata row
                Row(
                  children: [
                    Icon(Icons.person_outline, color: AppTheme.textSecondary, size: 13),
                    const SizedBox(width: 4),
                    Text('From: $meshOrigin', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    const Spacer(),
                    Icon(Icons.access_time, color: AppTheme.textSecondary, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      meshTime.length > 16 ? meshTime.substring(0, 16).replaceAll('T', ' ') : meshTime,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Dispatch Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showOfflineDispatchDialog(report);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.send_to_mobile, size: 16),
                    label: const Text('DISPATCH OFFLINE MATCH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return 'Just now';
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Recently';
    }
  }

  void _showOfflineDispatchDialog(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OFFLINE VOLUNTEER MATCH', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 16),
            const Text('Select a volunteer from local cache to dispatch via P2P Mesh.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: syncService.getOfflineVolunteers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                  }
                  final volunteers = snapshot.data ?? [];
                  if (volunteers.isEmpty) {
                    return const Center(
                      child: Text('No volunteers cached.\nPlease connect to internet once to sync.', 
                        textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                    );
                  }

                  return ListView.separated(
                    itemCount: volunteers.length,
                    separatorBuilder: (_, _) => const Divider(color: AppTheme.surfaceLow),
                    itemBuilder: (context, index) {
                      final v = volunteers[index];
                      String name = v['name'] ?? 'Unknown';
                      String skills = (v['skills'] as List<dynamic>?)?.join(', ') ?? 'No skills listed';
                      
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: AppTheme.primary, child: Icon(Icons.person, color: Colors.black)),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(skills, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        trailing: const Icon(Icons.send_rounded, color: AppTheme.primary, size: 20),
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          await syncService.dispatchMissionOffline(report, v['id'], name);
                          messenger.showSnackBar(SnackBar(
                            content: Text('📡 $name added to Offline Dispatch. Broadcasting Mesh Payload!'),
                            backgroundColor: Colors.blueAccent,
                          ));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
