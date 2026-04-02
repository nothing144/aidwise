import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_theme.dart';
import '../services/offline/offline_queue_service.dart';
import '../services/offline/bluetooth_mesh_service.dart';
import '../models/offline/offline_message.dart';
import '../models/offline/node_info.dart';

class AdminMissionsTab extends StatelessWidget {
  const AdminMissionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('missions').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading missions: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

          var missions = snapshot.data!.docs;
          if (missions.isEmpty) {
            return const Center(child: Text('No active or previous missions.', style: TextStyle(color: AppTheme.textSecondary)));
          }

          // Sort locally to avoid needing a Firestore composite index
          missions.sort((a, b) {
            Timestamp? tsA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            Timestamp? tsB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsB.compareTo(tsA); // descending
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: missions.length,
            itemBuilder: (context, index) {
              var doc = missions[index];
              var data = doc.data() as Map<String, dynamic>;
              String status = data['status'] ?? 'Pending';
              bool isCompleted = status == 'Completed';
              bool isVerified = status == 'Verified';

              Color statusColor = isVerified ? AppTheme.success 
                  : isCompleted ? Colors.orangeAccent 
                  : AppTheme.secondary;
              String statusText = status.toUpperCase();

              return Card(
                color: AppTheme.surface.withValues(alpha: 0.5),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 4,
                        height: double.infinity,
                        color: statusColor,
                      ),
                      title: Text(data['title'] ?? 'Mission', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['location'] ?? 'Unknown Area', style: const TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            if (data['description'] != null && data['description'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Text('"${data['description']}"', style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 13)),
                              ),
                            Text('Match Score: ${data['matchScore'] ?? 'N/A'}%', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ),
                    const Divider(color: AppTheme.surfaceLow, height: 1),
                    _buildDeliveryStatus(doc.id, data),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDeliveryStatus(String missionId, Map<String, dynamic> missionData) {
    return ValueListenableBuilder<int>(
      valueListenable: GetIt.I<OfflineQueueService>().pendingCount,
      builder: (context, _, child) {
        if (!Hive.isBoxOpen(OfflineQueueService.queueBoxName)) return const SizedBox.shrink();
        
        final box = Hive.box<OfflineMessage>(OfflineQueueService.queueBoxName);
        
        // Find if this mission has a dispatch message in the offline queue
        final messages = box.values.where((m) => 
          m.type == MessageType.dispatch && 
          m.payload['missionId'] == missionId
        ).toList();
        
        if (messages.isEmpty) return const SizedBox.shrink();
        
        // Sort by timestamp if there are multiple attempts
        messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final msg = messages.first;
        final mins = DateTime.now().difference(msg.timestamp).inMinutes;

        Widget statusWidget;

        if (msg.acked) {
          final hhmm = "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}";
          statusWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 14),
              const SizedBox(width: 6),
              Text('Delivered · $hhmm', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          );
        } else if (DateTime.now().difference(msg.timestamp) > msg.ttl) {
          statusWidget = Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 6),
                  const Text('Failed · TTL Expired', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  // Admin attempts reassign in a real prod
                },
                icon: const Icon(Icons.refresh, size: 14, color: AppTheme.primary),
                label: const Text('Reassign', style: TextStyle(color: AppTheme.primary, fontSize: 10)),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          );
        } else {
          final meshService = GetIt.I<BluetoothMeshService>();
          final route = meshService.routingTable.bestRouteFor(msg.toNodeId);
          bool hasRoute = route != null && route.status == NodeStatus.online;

          if (hasRoute) {
            statusWidget = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
                const SizedBox(width: 6),
                Text('Pending · Sent $mins min ago', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            );
          } else {
            statusWidget = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: Colors.grey, size: 14),
                const SizedBox(width: 6),
                const Text('Queued · Volunteer offline', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            );
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
          ),
          child: statusWidget,
        );
      },
    );
  }
}
