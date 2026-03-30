import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/offline_sync_service.dart';

/// Admin's offline P2P inbox — shows reports received via Bluetooth mesh
/// that haven't been synced to Firestore yet.
class AdminMeshInboxScreen extends StatelessWidget {
  const AdminMeshInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = OfflineSyncService();

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
              borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(width: 8),
                    // P2P Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bluetooth, color: Colors.blueAccent, size: 10),
                          SizedBox(width: 3),
                          Text('P2P', style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                      Icon(Icons.gps_fixed, color: AppTheme.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                        style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
