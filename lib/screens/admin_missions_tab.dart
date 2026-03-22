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
        stream: FirebaseFirestore.instance.collection('missions').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

          var missions = snapshot.data!.docs;
          if (missions.isEmpty) {
            return const Center(child: Text('No active or previous missions.', style: TextStyle(color: AppTheme.textSecondary)));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: missions.length,
            itemBuilder: (context, index) {
              var doc = missions[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isCompleted = data['status'] == 'Completed';

              return Card(
                color: AppTheme.surface.withValues(alpha: 0.5),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: Border(left: BorderSide(color: isCompleted ? AppTheme.success : AppTheme.secondary, width: 4)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(data['title'] ?? 'Mission', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['location'] ?? 'Unknown Area', style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Assigned Vol: ${data['assignedVolunteerId']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isCompleted ? AppTheme.success : AppTheme.secondary),
                    ),
                    child: Text(data['status']?.toUpperCase() ?? 'PENDING', style: TextStyle(color: isCompleted ? AppTheme.success : AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 10)),
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
