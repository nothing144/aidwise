import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'report_detail_map_screen.dart';
import '../services/auth_service.dart';

class HeatmapDashboard extends StatelessWidget {
  final bool showAppBar;
  
  const HeatmapDashboard({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            if (showAppBar) _buildTopBar(),
            if (showAppBar) const SizedBox(height: 16),
            _buildMetricsRow(),
            const SizedBox(height: 24),
            Expanded(
              child: _buildAIPriorityList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('AIDWISE CORE', style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 18,
                shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)],
              )),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.urgencyLow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.urgencyLow.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.urgencyLow, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('SYSTEM ONLINE', style: TextStyle(color: AppTheme.urgencyLow, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary, size: 20),
            onPressed: () => AuthService().signOut(),
          )
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Expanded(child: _buildMetricCard('Unprocessed\nReports', '12', AppTheme.secondary)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Critical\nHotspots', '3', AppTheme.urgencyHigh)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Active\nVolunteers', '84', AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppTheme.glassmorphismShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(
            color: color, 
            fontSize: 24, 
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
          )),
        ],
      ),
    );
  }

  Widget _buildAIPriorityList(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        border: const Border(top: BorderSide(color: AppTheme.primary, width: 2)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 24),
              const SizedBox(width: 10),
              const Text('AI PRIORITY RANKINGS', style: TextStyle(
                color: AppTheme.primary, 
                fontWeight: FontWeight.w900, 
                letterSpacing: 2.0,
              )),
              const Spacer(),
              const Text('FIELD REPORTS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5))
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('reports').where('status', isEqualTo: 'Open').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                
                var allDocs = snapshot.data?.docs ?? [];
                // ONLY show Field Worker reports (not Admin Dashboard reports)
                var fieldDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['source'] != 'Admin Dashboard';
                }).toList();
                
                if (fieldDocs.isEmpty) {
                  return const Center(
                    child: Text('No active field hotspots detected.', style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Padding for bottom nav
                  itemCount: fieldDocs.length,
                  itemBuilder: (context, index) {
                    var doc = fieldDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    String urgencyStr = data['urgency'] ?? 'Medium';
                    Color uColor = urgencyStr == 'High' ? AppTheme.urgencyHigh : AppTheme.urgencyMedium;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildHotspotRow(
                        context, 
                        data,
                        uColor,
                        doc.id
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotRow(BuildContext context, Map<String, dynamic> data, Color urgencyColor, String reportId) {
    bool hasCoords = data.containsKey('latitude') && data.containsKey('longitude');
    String location = data['location'] ?? 'Unknown Location';
    String need = data['type'] ?? 'General Need';

    return GestureDetector(
      onTap: hasCoords ? () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailMapScreen(
          reportId: reportId,
          reportType: need,
          location: location,
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
          urgency: data['urgency'] ?? 'High',
        )));
      } : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.stitchCardWithLeftBorder(urgencyColor),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: urgencyColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: urgencyColor, blurRadius: 5)]),
                    ),
                    const SizedBox(width: 8),
                    Text(location, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Need: $need', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: const Text('98%', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..strokeWidth = 1.0;

    double step = 30.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
