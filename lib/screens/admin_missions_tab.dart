import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

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
                child: ListTile(
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
              );
            },
          );
        },
      ),
    );
  }
}
