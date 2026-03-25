import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'ai_scanner_screen.dart';
import 'report_detail_map_screen.dart';

class AdminReportsTab extends StatelessWidget {
  const AdminReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AIScannerScreen(isAdminMode: true)));
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.document_scanner, color: Colors.black),
        label: const Text('DIGITIZE REPORT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

          var allReports = snapshot.data!.docs;
          var reports = allReports.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['source'] == 'Admin Dashboard';
          }).toList();

          if (reports.isEmpty) {
            return const Center(child: Text('No office reports pinned yet.', style: TextStyle(color: AppTheme.textSecondary)));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, top: 16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              var doc = reports[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isOffice = data['source'] == 'Admin Dashboard';
              bool isOpen = data['status'] == 'Open';
              bool hasCoords = data.containsKey('latitude') && data.containsKey('longitude');

              Color statusColor = isOpen ? AppTheme.urgencyHigh : AppTheme.success;

              return GestureDetector(
                onTap: hasCoords ? () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailMapScreen(
                    reportId: doc.id,
                    reportType: data['type'] ?? 'Emergency',
                    location: data['location'] ?? 'Unknown',
                    latitude: (data['latitude'] as num).toDouble(),
                    longitude: (data['longitude'] as num).toDouble(),
                    urgency: data['urgency'] ?? 'High',
                  )));
                } : null,
                child: Card(
                  color: AppTheme.surface.withValues(alpha: 0.5),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.surfaceLow)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: isOffice ? AppTheme.secondary.withValues(alpha: 0.2) : AppTheme.primary.withValues(alpha: 0.2),
                      child: Icon(isOffice ? Icons.business : Icons.gps_fixed, color: isOffice ? AppTheme.secondary : AppTheme.primary),
                    ),
                    title: Text(data['type'] ?? 'Emergency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['location'] ?? 'Unknown Location', style: const TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(data['status']?.toUpperCase() ?? 'UNKNOWN', style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.primary),
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
